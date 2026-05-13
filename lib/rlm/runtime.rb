# frozen_string_literal: true

require_relative "code_extractor"
require_relative "context"
require_relative "errors"
require_relative "file"
require_relative "limits"
require_relative "prompt_builder"
require_relative "result"
require_relative "runtime/bridge"
require_relative "runtime/signature_registry"
require_relative "signature"
require_relative "trace"

module RLM
  class Runtime
    def initialize(
      signature:,
      input:,
      lm:,
      sandbox:,
      limits:,
      sub_lm: nil,
      context: nil,
      tools: [],
      skills: [],
      validators: [],
      signatures: [],
      depth: 0
    )
      @signature = signature
      @input = input || {}
      @lm = lm
      @sub_lm = sub_lm || lm
      @sandbox = sandbox
      @limits = limits || Limits.new
      @context = context || build_context(@input)
      @tools = Array(tools)
      @skills = Array(skills)
      @validators = Array(validators)
      @signatures = SignatureRegistry.build(signature, signatures)
      @depth = depth
      @trace = Trace.new
      @iterations = 0
      @llm_calls = 0
    end

    def call
      raise ProviderError, "root LM is required" if lm.nil?

      start_run
      bridge = prepare_sandbox
      run_loop(bridge)
    rescue BudgetExceededError => e
      finish(:budget_exceeded, error: e)
    rescue ProviderError => e
      finish(:provider_error, error: e)
    rescue SandboxError => e
      finish(:sandbox_error, error: e)
    rescue ValidationError => e
      validation_failure([e.message], e)
    rescue ParseError, ConfigurationError => e
      finish(:aborted, error: e)
    ensure
      sandbox&.cleanup
    end

    def predict_subcall(signature, input, depth:)
      raise BudgetExceededError, "max_recursion_depth exceeded" if depth > limits.max_recursion_depth
      raise ProviderError, "sub LM is required" if sub_lm.nil?

      parsed = call_sub_lm(signature, input, depth)
      raise ValidationError, "sub LM must return <rlm-final> in v0.2 mock runtime" unless parsed.final?

      validate_output!(signature, parsed.content)
      parsed.content
    end

    private

    attr_reader :signature, :input, :lm, :sub_lm, :context, :tools, :skills,
                :sandbox, :limits, :validators, :signatures, :depth, :trace,
                :iterations, :llm_calls

    def start_run
      trace.record(:run_started, signature: Signature.name_for(signature), input: input)
      validate_root_input!
    end

    def prepare_sandbox
      bridge = Bridge.new(
        runtime: self,
        context: context,
        trace: trace,
        tools: tools,
        signatures: signatures,
        depth: depth
      )
      sandbox.prepare(context: context, tools: tools, skills: skills, runtime_bridge: bridge)
      bridge
    end

    def run_loop(bridge)
      loop do
        parsed = call_root_lm
        return complete(parsed.content) if parsed.final?

        execute_code(parsed.content)
        return complete(bridge.submitted_output) unless bridge.submitted_output.nil?
      end
    end

    def call_root_lm
      ensure_llm_budget!
      prompt = PromptBuilder.build(signature, input: input, context: context, limits: limits)
      trace.record(:root_prompt_created, bytes: prompt.bytesize)
      response = call_lm(lm, :root_lm_called, signature, prompt, depth)
      CodeExtractor.extract(response)
    end

    def call_sub_lm(checked_signature, payload, sub_depth)
      ensure_llm_budget!
      prompt = PromptBuilder.build(checked_signature, input: payload, context: context, limits: limits)
      response = call_lm(sub_lm, :sub_lm_called, checked_signature, prompt, sub_depth)
      CodeExtractor.extract(response)
    end

    def call_lm(candidate, event_type, checked_signature, prompt, call_depth)
      before_cost = candidate.cost_cents if candidate.respond_to?(:cost_cents)
      response = candidate.call(prompt: prompt, signature: Signature.name_for(checked_signature), depth: call_depth)
      @llm_calls += 1
      trace.record(
        event_type,
        signature: Signature.name_for(checked_signature),
        cost_cents: cost_delta(candidate, before_cost)
      )
      response
    end

    def execute_code(code)
      raise BudgetExceededError, "max_iterations exceeded" if iterations >= limits.max_iterations

      @iterations += 1
      trace.record(:code_generated, code: code)
      result = sandbox.exec(code)
      trace.record(:code_executed, result: result.to_h)
      handle_sandbox_result!(result)
    end

    def handle_sandbox_result!(result)
      return if result.ok?
      raise result.error if result.error.is_a?(BudgetExceededError)

      raise SandboxError, result.error&.message || result.stderr || "sandbox execution failed"
    end

    def complete(output)
      errors = validate_output(signature, output)
      return validation_failure(errors) unless errors.empty?

      trace.record(:run_completed, status: :completed)
      finish(:completed, output: output)
    end

    def validate_root_input!
      trace.record(:validation_attempted, signature: Signature.name_for(signature), direction: :input)
      errors = Signature.validate_input(signature, input)
      return if errors.empty?

      trace.record(:validation_failed, signature: Signature.name_for(signature), direction: :input, errors: errors)
      raise ValidationError, errors.join(", ")
    end

    def validate_output!(checked_signature, output)
      errors = validate_output(checked_signature, output)
      raise ValidationError, errors.join(", ") unless errors.empty?
    end

    def validate_output(checked_signature, output)
      trace.record(:validation_attempted, signature: Signature.name_for(checked_signature), direction: :output)
      all_errors = Signature.validate_output(checked_signature, output) + custom_validation_errors(output)
      record_validation_failure(checked_signature, all_errors) unless all_errors.empty?
      all_errors
    end

    def custom_validation_errors(output)
      validators.flat_map { |validator| Array(validator.call(output)) }
    end

    def record_validation_failure(checked_signature, errors)
      trace.record(
        :validation_failed,
        signature: Signature.name_for(checked_signature),
        direction: :output,
        errors: errors
      )
    end

    def validation_failure(errors, error = nil)
      trace.record(:run_failed, status: :failed_validation, errors: errors)
      finish(:failed_validation, validation_errors: errors, error: error)
    end

    def finish(status, output: nil, error: nil, validation_errors: [])
      Result.new(
        trace: trace,
        status: status,
        output: output,
        error: error,
        cost_cents: runtime_cost_cents,
        duration_ms: trace.duration_ms,
        llm_calls: llm_calls,
        iterations: iterations,
        validation_errors: validation_errors
      )
    end

    def ensure_llm_budget!
      raise BudgetExceededError, "max_llm_calls exceeded" if llm_calls >= limits.max_llm_calls
    end

    def runtime_cost_cents
      [lm, sub_lm].compact.uniq.sum do |candidate|
        candidate.respond_to?(:cost_cents) ? candidate.cost_cents : 0
      end
    end

    def cost_delta(candidate, before_cost)
      return 0 unless candidate.respond_to?(:cost_cents)

      candidate.cost_cents - before_cost.to_i
    end

    def build_context(payload)
      Context.new(inputs: payload, files: payload.values.grep(RLM::File))
    end
  end
end
