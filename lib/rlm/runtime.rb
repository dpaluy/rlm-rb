# frozen_string_literal: true

require_relative "code_extractor"
require_relative "context"
require_relative "errors"
require_relative "file"
require_relative "limits"
require_relative "prompt_builder"
require_relative "result"
require_relative "runtime/budgets"
require_relative "runtime/bridge"
require_relative "runtime/execution"
require_relative "runtime/finish"
require_relative "runtime/lm_calls"
require_relative "runtime/signature_registry"
require_relative "runtime/validation"
require_relative "signature"
require_relative "trace"
require_relative "tool_registry"

module RLM
  class Runtime
    include Runtime::Budgets
    include Runtime::Execution
    include Runtime::Finish
    include Runtime::LmCalls
    include Runtime::Validation

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
      trace_store: nil,
      tool_authorizer: nil
    )
      @signature = signature
      @input = input || {}
      @lm = lm
      @sub_lm = sub_lm || lm
      @sandbox = sandbox
      @limits = limits || Limits.new
      @context = context || build_context(@input)
      @tools = tools.is_a?(ToolRegistry) ? tools : Array(tools)
      @skills = Array(skills)
      @validators = Array(validators)
      @signatures = SignatureRegistry.build(signature, signatures)
      @depth = depth
      @trace_store = trace_store
      @tool_authorizer = tool_authorizer
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
                :iterations, :llm_calls, :sub_lm_calls, :trace_store, :tool_authorizer
  end
end
