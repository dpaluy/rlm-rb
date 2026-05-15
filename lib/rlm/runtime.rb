# frozen_string_literal: true

require "json"

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
  # rubocop:disable Metrics/ClassLength
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
      depth: 0,
      trace_store: nil
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
      @trace_store = trace_store
      @trace = Trace.new
      @iterations = 0
      @llm_calls = 0
      @sub_lm_calls = 0
      @tool_calls = 0
      @last_submitted_output = nil
    end

    def call
      raise ProviderError, "root LM is required" if lm.nil?

      start_run
      bridge = prepare_sandbox
      run_loop(bridge)
    rescue BudgetExceededError => e
      budget_exceeded_result(e)
    rescue ToolError => e
      finish(:tool_error, error: e)
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

      output = Signature.coerce_output(signature, parsed.content)
      validate_output!(signature, output)
      output
    end

    def record_tool_attempt!
      trace.record(:budget_checked, budget: :tool_calls, current: @tool_calls, limit: limits.max_tool_calls)
      raise BudgetExceededError, "max_tool_calls exceeded" if @tool_calls >= limits.max_tool_calls

      @tool_calls += 1
    end

    def record_submitted_output(output)
      @last_submitted_output = output
    end

    private

    attr_reader :signature, :input, :lm, :sub_lm, :context, :tools, :skills,
                :sandbox, :limits, :validators, :signatures, :depth, :trace,
                :iterations, :llm_calls, :sub_lm_calls, :trace_store

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
        ensure_time_budget!
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
      ensure_sub_lm_budget!
      prompt = PromptBuilder.build(checked_signature, input: payload, context: context, limits: limits)
      response = call_lm(sub_lm, :sub_lm_called, checked_signature, prompt, sub_depth)
      @sub_lm_calls += 1
      CodeExtractor.extract(response)
    end

    def call_lm(candidate, event_type, checked_signature, prompt, call_depth)
      before_cost = candidate.cost_cents if candidate.respond_to?(:cost_cents)
      response = candidate.call(prompt: prompt, signature: Signature.name_for(checked_signature), depth: call_depth)
      @llm_calls += 1
      payload = {
        signature: Signature.name_for(checked_signature),
        cost_cents: cost_delta(candidate, before_cost)
      }
      payload[:usage] = candidate.last_usage if candidate.respond_to?(:last_usage) && candidate.last_usage
      trace.record(event_type, payload)
      ensure_cost_budget!
      response
    end

    def execute_code(code)
      ensure_time_budget!
      trace.record(:budget_checked, budget: :iterations, current: iterations, limit: limits.max_iterations)
      raise BudgetExceededError, "max_iterations exceeded" if iterations >= limits.max_iterations

      @iterations += 1
      trace.record(:code_generated, code: code)
      result = sandbox.exec(code)
      ensure_stdout_budget!(result)
      trace.record(:code_executed, result: result.to_h)
      handle_sandbox_result!(result)
    end

    def handle_sandbox_result!(result)
      return if result.ok?

      case result.error
      when BudgetExceededError, ParseError, ToolError
        raise result.error
      else
        raise SandboxError, result.error&.message || result.stderr || "sandbox execution failed"
      end
    end

    def complete(output)
      coerced_output = Signature.coerce_output(signature, output)
      ensure_output_budget!(coerced_output)
      errors = validate_output(signature, coerced_output)
      return validation_failure(errors) unless errors.empty?

      trace.record(:run_completed, status: :completed)
      finish(:completed, output: coerced_output)
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
      finish(:failed_validation, validation_errors: errors, error: error)
    end

    def finish(status, output: nil, error: nil, validation_errors: [])
      record_run_failed(status, error:, validation_errors:) unless status == :completed

      result = Result.new(
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
      persist_trace(result)
      result
    end

    def ensure_llm_budget!
      trace.record(:budget_checked, budget: :llm_calls, current: llm_calls, limit: limits.max_llm_calls)
      raise BudgetExceededError, "max_llm_calls exceeded" if llm_calls >= limits.max_llm_calls
    end

    def ensure_sub_lm_budget!
      trace.record(:budget_checked, budget: :sub_lm_calls, current: sub_lm_calls, limit: limits.max_sub_lm_calls)
      raise BudgetExceededError, "max_sub_lm_calls exceeded" if sub_lm_calls >= limits.max_sub_lm_calls
    end

    def ensure_cost_budget!
      current_cost = runtime_cost_cents
      trace.record(:budget_checked, budget: :cost_cents, current: current_cost, limit: limits.max_cost_cents)
      raise BudgetExceededError, "max_cost_cents exceeded" if current_cost >= limits.max_cost_cents
    end

    def ensure_time_budget!
      current_ms = trace.duration_ms
      limit_ms = limits.max_runtime_seconds * 1000
      trace.record(:budget_checked, budget: :runtime_seconds, current: current_ms, limit: limit_ms)
      raise BudgetExceededError, "max_runtime_seconds exceeded" if current_ms >= limit_ms
    end

    def ensure_output_budget!(output)
      current_bytes = JSON.generate(output).bytesize
      trace.record(:budget_checked, budget: :output_bytes, current: current_bytes, limit: limits.max_output_bytes)
      raise BudgetExceededError, "max_output_bytes exceeded" if current_bytes > limits.max_output_bytes
    end

    def ensure_stdout_budget!(result)
      current_bytes = result.stdout.to_s.bytesize
      trace.record(:budget_checked, budget: :stdout_bytes, current: current_bytes, limit: limits.max_stdout_bytes)
      raise BudgetExceededError, "max_stdout_bytes exceeded" if current_bytes > limits.max_stdout_bytes
    end

    def budget_exceeded_result(error)
      case limits.on_budget_exceeded
      when :needs_review
        finish(:needs_review, output: valid_last_submitted_output, error: error)
      when :return_partial
        output = valid_last_submitted_output
        return finish(:needs_review, output: output, error: error) unless output.nil?

        finish(:budget_exceeded, error: error)
      else
        finish(:budget_exceeded, error: error)
      end
    end

    def valid_last_submitted_output
      return if @last_submitted_output.nil?
      return if validate_output(signature, @last_submitted_output).any?

      ensure_output_budget!(@last_submitted_output)
      @last_submitted_output
    rescue BudgetExceededError
      nil
    end

    def persist_trace(result)
      return unless trace_store.respond_to?(:call)

      trace_store.call(result)
    rescue StandardError
      nil
    end

    def record_run_failed(status, error:, validation_errors: [])
      payload = { status: status }
      payload[:error] = trace_error_payload(error) if error
      payload[:errors] = validation_errors if validation_errors.any?
      trace.record(:run_failed, payload)
    end

    def trace_error_payload(error)
      { class: error.class.name, message: error.message }
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
  # rubocop:enable Metrics/ClassLength
end
