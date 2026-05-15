# frozen_string_literal: true

require "test_helper"

module RuntimeTraceAssertions
  def event_types(result) = result.trace.events.map { |event| event[:type] }

  def expected_code_run_events
    %i[
      run_started
      validation_attempted
      budget_checked
      budget_checked
      root_prompt_created
      root_lm_called
      budget_checked
      budget_checked
      budget_checked
      code_generated
      validation_attempted
      budget_checked
      budget_checked
      sub_lm_called
      budget_checked
      validation_attempted
      output_submitted
      budget_checked
      code_executed
      budget_checked
      validation_attempted
      run_completed
    ]
  end

  def expected_budget_failure_events
    %i[
      run_started
      validation_attempted
      budget_checked
      budget_checked
      root_prompt_created
      root_lm_called
      budget_checked
      budget_checked
      budget_checked
      code_generated
      validation_attempted
      budget_checked
      budget_checked
      code_executed
      run_failed
    ]
  end

  def expected_validation_failure_events
    %i[
      run_started
      validation_attempted
      budget_checked
      budget_checked
      root_prompt_created
      root_lm_called
      budget_checked
      budget_checked
      validation_attempted
      validation_failed
      run_failed
    ]
  end

  def expected_parse_failure_events
    %i[
      run_started
      validation_attempted
      budget_checked
      budget_checked
      root_prompt_created
      root_lm_called
      budget_checked
      run_failed
    ]
  end

  def assert_budget_failure_trace(result)
    assert_equal :budget_exceeded, result.trace.events.last[:payload][:status]
    assert_equal "RLM::BudgetExceededError", result.trace.events.last[:payload][:error][:class]
  end

  def assert_budget_exhaustion_result(result)
    assert_equal :budget_exceeded, result.status
    assert result.failed?
    assert_equal 1, result.llm_calls
    assert_equal expected_budget_failure_events, event_types(result)
    assert_budget_failure_trace(result)
  end
end

# rubocop:disable Metrics/ClassLength
class RLM::RuntimeTest < Minitest::Test
  include RuntimeTraceAssertions

  TrackingSandbox = Class.new(RLM::Sandbox::UnsafeInProcess) do
    attr_reader :cleanup_called

    def initialize(exec_result: nil)
      super()
      @exec_result = exec_result
      @cleanup_called = false
    end

    def cleanup
      @cleanup_called = true
      super
    end

    def exec(code)
      return @exec_result if @exec_result

      super
    end
  end

  RootSignature = Class.new do
    def self.name = "RootSignature"
    def self.description = "Root runtime test"
    def self.input_fields = { text: :string }
    def self.output_fields = { summary: :string }
    def self.validate_input(input) = input.key?(:text) || input.key?("text") ? [] : ["text is required"]
    def self.validate_output(output) = output.key?(:summary) || output.key?("summary") ? [] : ["summary is required"]
  end

  SubSignature = Class.new do
    def self.name = "SubSignature"
    def self.description = "Sub runtime test"
    def self.input_fields = { text: :string }
    def self.output_fields = { summary: :string }
    def self.validate_input(input) = input.key?(:text) || input.key?("text") ? [] : ["text is required"]
    def self.validate_output(output) = output.key?(:summary) || output.key?("summary") ? [] : ["summary is required"]
  end

  SymbolOutputSignature = Class.new do
    def self.name = "SymbolOutputSignature"
    def self.description = "Coerces string-keyed JSON into symbol-keyed output"
    def self.input_fields = { text: :string }
    def self.output_fields = { summary: :string }
    def self.validate_input(input) = input.key?(:text) || input.key?("text") ? [] : ["text is required"]
    def self.validate_output(output) = output.key?(:summary) ? [] : ["summary is required"]
    def self.coerce_output(output) = output.transform_keys(&:to_sym)
  end

  UsageLm = Class.new do
    attr_reader :cost_cents, :last_usage

    def initialize(responses:, usage:, cost_cents: 0)
      @responses = responses.dup
      @usage = usage
      @cost_cents_per_call = cost_cents
      @cost_cents = 0
      @last_usage = nil
    end

    def call(prompt:, **)
      raise RLM::ProviderError, "prompt must be a String" unless prompt.is_a?(String)

      @cost_cents += @cost_cents_per_call
      @last_usage = @usage
      @responses.shift
    end
  end

  FailingTool = Class.new(RLM::Tool) do
    def call
      raise RLM::ToolError, "tool boom"
    end
  end

  InvalidCoercingRootSignature = Class.new(RootSignature) do
    def self.coerce_output(_output)
      { "wrong" => "shape" }
    end
  end

  def test_runs_code_response_through_sandbox_and_returns_submitted_output
    lm = RLM::Lm::Mock.new(responses: [root_code_response], cost_cents: 2)
    sub_lm = RLM::Lm::Mock.new(responses: ['<rlm-final>{"summary":"sub ok"}</rlm-final>'], cost_cents: 3)
    sandbox = tracking_sandbox

    result = RLM.predict(
      RootSignature,
      input: { text: "hello" },
      lm: lm,
      sub_lm: sub_lm,
      sandbox: sandbox,
      signatures: [SubSignature],
      limits: RLM::Limits.new(max_iterations: 2, max_llm_calls: 2)
    )

    assert result.success?
    assert_equal({ "summary" => "sub ok" }, result.output)
    assert_equal 2, result.llm_calls
    assert_equal 5, result.cost_cents
    assert_equal expected_code_run_events, event_types(result)
    assert sandbox.cleanup_called
  end

  def test_direct_final_response_completes_without_sandbox_execution
    lm = RLM::Lm::Mock.new(responses: ['<rlm-final>{"summary":"done"}</rlm-final>'])
    sandbox = tracking_sandbox

    result = RLM.predict(RootSignature, input: { text: "hello" }, lm: lm, sandbox: sandbox)

    assert result.success?
    assert_equal({ "summary" => "done" }, result.output)
    assert sandbox.cleanup_called
  end

  def test_root_lm_trace_includes_usage_when_available
    usage = { model_id: "openai/gpt-5-mini", input_tokens: 10, output_tokens: 4, cost_cents: 2, cost_known: true }
    lm = UsageLm.new(responses: ['<rlm-final>{"summary":"done"}</rlm-final>'], usage: usage, cost_cents: 2)

    result = RLM.predict(RootSignature, input: { text: "hello" }, lm: lm, sandbox: tracking_sandbox)

    event = result.trace.events.find { |candidate| candidate[:type] == :root_lm_called }
    assert_equal usage, event[:payload][:usage]
    assert_equal 2, event[:payload][:cost_cents]
  end

  def test_sub_lm_trace_includes_usage_when_available
    usage = { model_id: "openai/gpt-5-mini", input_tokens: 8, output_tokens: 5, cost_cents: 3, cost_known: true }
    lm = RLM::Lm::Mock.new(responses: [root_code_response])
    sub_lm = UsageLm.new(responses: ['<rlm-final>{"summary":"sub ok"}</rlm-final>'], usage: usage, cost_cents: 3)

    result = RLM.predict(
      RootSignature,
      input: { text: "hello" },
      lm: lm,
      sub_lm: sub_lm,
      sandbox: tracking_sandbox,
      signatures: [SubSignature],
      limits: RLM::Limits.new(max_iterations: 2, max_llm_calls: 2)
    )

    event = result.trace.events.find { |candidate| candidate[:type] == :sub_lm_called }
    assert_equal usage, event[:payload][:usage]
    assert_equal 3, event[:payload][:cost_cents]
  end

  def test_mock_lm_trace_omits_usage
    result = RLM.predict(
      RootSignature,
      input: { text: "hello" },
      lm: RLM::Lm::Mock.new(responses: ['<rlm-final>{"summary":"done"}</rlm-final>']),
      sandbox: tracking_sandbox
    )

    event = result.trace.events.find { |candidate| candidate[:type] == :root_lm_called }
    refute_includes event[:payload], :usage
  end

  def test_root_final_output_is_coerced_before_validation
    result = RLM.predict(
      SymbolOutputSignature,
      input: { text: "hello" },
      lm: RLM::Lm::Mock.new(responses: ['<rlm-final>{"summary":"done"}</rlm-final>']),
      sandbox: tracking_sandbox
    )

    assert result.success?
    assert_equal({ summary: "done" }, result.output)
  end

  def test_budget_exhaustion_returns_budget_result
    lm = RLM::Lm::Mock.new(responses: [root_code_response])
    sub_lm = RLM::Lm::Mock.new(responses: ['<rlm-final>{"summary":"sub ok"}</rlm-final>'])
    sandbox = tracking_sandbox

    result = RLM.predict(
      RootSignature,
      input: { text: "hello" },
      lm: lm,
      sub_lm: sub_lm,
      sandbox: sandbox,
      signatures: [SubSignature],
      limits: RLM::Limits.new(max_iterations: 2, max_llm_calls: 1, on_budget_exceeded: :fail)
    )

    assert_budget_exhaustion_result(result)
    assert sandbox.cleanup_called
  end

  def test_validation_failure_returns_failed_validation_result
    lm = RLM::Lm::Mock.new(responses: ['<rlm-final>{"wrong":"shape"}</rlm-final>'])
    sandbox = tracking_sandbox

    result = RLM.predict(RootSignature, input: { text: "hello" }, lm: lm, sandbox: sandbox)

    assert_equal :failed_validation, result.status
    assert_equal ["summary is required"], result.validation_errors
    assert_equal expected_validation_failure_events, event_types(result)
    assert_equal :failed_validation, result.trace.events.last[:payload][:status]
    assert_equal ["summary is required"], result.trace.events.last[:payload][:errors]
    assert sandbox.cleanup_called
  end

  def test_parse_failure_records_run_failed_event
    lm = RLM::Lm::Mock.new(responses: ["not a trace block"])
    sandbox = tracking_sandbox

    result = RLM.predict(RootSignature, input: { text: "hello" }, lm: lm, sandbox: sandbox)

    assert_equal :aborted, result.status
    assert_equal expected_parse_failure_events, event_types(result)
    assert_equal :aborted, result.trace.events.last[:payload][:status]
    assert_equal "RLM::ParseError", result.trace.events.last[:payload][:error][:class]
    assert sandbox.cleanup_called
  end

  def test_provider_failure_cleans_up_sandbox
    lm = Class.new do
      def call(*)
        raise RLM::ProviderError, "provider boom"
      end
    end.new
    sandbox = tracking_sandbox

    result = RLM.predict(RootSignature, input: { text: "hello" }, lm: lm, sandbox: sandbox)

    assert_equal :provider_error, result.status
    assert_instance_of RLM::ProviderError, result.error
    assert sandbox.cleanup_called
  end

  def test_invalid_coercion_result_fails_closed_through_validation
    result = RLM.predict(
      InvalidCoercingRootSignature,
      input: { text: "hello" },
      lm: RLM::Lm::Mock.new(responses: ['<rlm-final>{"summary_text":"done"}</rlm-final>']),
      sandbox: tracking_sandbox
    )

    assert_equal :failed_validation, result.status
    assert_equal ["summary is required"], result.validation_errors
  end

  def test_budget_exhaustion_at_llm_budget_cleans_up_sandbox
    lm = RLM::Lm::Mock.new(responses: ['<rlm-final>{"summary":"done"}</rlm-final>'])
    sandbox = tracking_sandbox

    result = RLM.predict(
      RootSignature,
      input: { text: "hello" },
      lm: lm,
      sandbox: sandbox,
      limits: RLM::Limits.new(max_llm_calls: 0, on_budget_exceeded: :fail)
    )

    assert_equal :budget_exceeded, result.status
    assert sandbox.cleanup_called
  end

  def test_sandbox_error_cleans_up_sandbox
    lm = RLM::Lm::Mock.new(responses: [root_code_response])
    sandbox = tracking_sandbox(
      exec_result: RLM::Sandbox::ExecutionResult.new(
        status: :error,
        stderr: "sandbox boom",
        error: RuntimeError.new("sandbox boom"),
        exit_code: 1
      )
    )

    result = RLM.predict(
      RootSignature,
      input: { text: "hello" },
      lm: lm,
      sub_lm: RLM::Lm::Mock.new(responses: ['<rlm-final>{"summary":"sub ok"}</rlm-final>']),
      sandbox: sandbox,
      signatures: [SubSignature],
      limits: RLM::Limits.new(max_iterations: 2, max_llm_calls: 2)
    )

    assert_equal :sandbox_error, result.status
    assert_instance_of RLM::SandboxError, result.error
    assert sandbox.cleanup_called
  end

  def test_cost_budget_exceeded_returns_budget_result
    lm = RLM::Lm::Mock.new(responses: ['<rlm-final>{"summary":"done"}</rlm-final>'], cost_cents: 101)
    sandbox = tracking_sandbox

    result = RLM.predict(
      RootSignature,
      input: { text: "hello" },
      lm: lm,
      sandbox: sandbox,
      limits: RLM::Limits.new(max_cost_cents: 100, on_budget_exceeded: :fail)
    )

    assert_equal :budget_exceeded, result.status
    assert result.failed?
    assert sandbox.cleanup_called
  end

  def test_output_budget_exceeded_returns_budget_result
    lm = RLM::Lm::Mock.new(responses: ['<rlm-final>{"summary":"too large"}</rlm-final>'])
    sandbox = tracking_sandbox

    result = RLM.predict(
      RootSignature,
      input: { text: "hello" },
      lm: lm,
      sandbox: sandbox,
      limits: RLM::Limits.new(max_output_bytes: 10, on_budget_exceeded: :fail)
    )

    assert_equal :budget_exceeded, result.status
    assert_equal :output_bytes, result.trace.events.last(2).first[:payload][:budget]
    assert_budget_failure_trace(result)
    assert sandbox.cleanup_called
  end

  def test_stdout_budget_exceeded_returns_budget_result
    lm = RLM::Lm::Mock.new(responses: [root_code_response])
    sandbox = tracking_sandbox(
      exec_result: RLM::Sandbox::ExecutionResult.new(stdout: "x" * 11)
    )

    result = RLM.predict(
      RootSignature,
      input: { text: "hello" },
      lm: lm,
      sandbox: sandbox,
      signatures: [SubSignature],
      limits: RLM::Limits.new(max_stdout_bytes: 10, on_budget_exceeded: :fail)
    )

    assert_equal :budget_exceeded, result.status
    assert_equal :stdout_bytes, result.trace.events.last(2).first[:payload][:budget]
    assert_budget_failure_trace(result)
    assert sandbox.cleanup_called
  end

  def test_time_budget_exceeded_returns_budget_result
    start_time = Time.now
    clock = proc { start_time }
    lm = RLM::Lm::Mock.new(responses: ['<rlm-final>{"summary":"done"}</rlm-final>'])
    sandbox = tracking_sandbox

    runtime = RLM::Runtime.new(
      signature: RootSignature,
      input: { text: "hello" },
      lm: lm,
      sandbox: sandbox,
      limits: RLM::Limits.new(max_runtime_seconds: 0, on_budget_exceeded: :fail),
      context: RLM::Context.new(inputs: { text: "hello" })
    )

    runtime.instance_variable_set(:@trace, RLM::Trace.new(clock: clock))
    result = runtime.call

    assert_equal :budget_exceeded, result.status
    assert result.failed?
    assert sandbox.cleanup_called
  end

  def test_subcall_parse_failure_returns_aborted_result
    lm = RLM::Lm::Mock.new(responses: [root_code_response])
    sub_lm = RLM::Lm::Mock.new(responses: ["not a valid block"])
    sandbox = tracking_sandbox

    result = RLM.predict(
      RootSignature,
      input: { text: "hello" },
      lm: lm,
      sub_lm: sub_lm,
      sandbox: sandbox,
      signatures: [SubSignature],
      limits: RLM::Limits.new(max_iterations: 2, max_llm_calls: 2)
    )

    assert_equal :aborted, result.status
    assert sandbox.cleanup_called
  end

  def test_sub_lm_output_is_coerced_before_returning_to_sandbox_code
    root_signature = Class.new(RootSignature) do
      def self.validate_output(output) = output.key?(:summary) ? [] : ["summary is required"]
    end
    root_signature.define_singleton_method(:name) { "RootSymbolSignature" }
    sub_signature = Class.new(SymbolOutputSignature)
    sub_signature.define_singleton_method(:name) { "SubSymbolSignature" }
    root_response = <<~RESPONSE
      <rlm-code>
        sub = predict("SubSymbolSignature", { "text" => "hello" })
        submit({ summary: sub.fetch(:summary) })
      </rlm-code>
    RESPONSE

    result = RLM.predict(
      root_signature,
      input: { text: "hello" },
      lm: RLM::Lm::Mock.new(responses: [root_response]),
      sub_lm: RLM::Lm::Mock.new(responses: ['<rlm-final>{"summary":"sub ok"}</rlm-final>']),
      sandbox: tracking_sandbox,
      signatures: [sub_signature],
      limits: RLM::Limits.new(max_iterations: 2, max_llm_calls: 2)
    )

    assert result.success?
    assert_equal({ summary: "sub ok" }, result.output)
  end

  def test_max_sub_lm_calls_blocks_recursive_subcalls
    lm = RLM::Lm::Mock.new(responses: [root_code_response])
    sub_lm = RLM::Lm::Mock.new(responses: ['<rlm-final>{"summary":"sub ok"}</rlm-final>'])

    result = RLM.predict(
      RootSignature,
      input: { text: "hello" },
      lm: lm,
      sub_lm: sub_lm,
      sandbox: tracking_sandbox,
      signatures: [SubSignature],
      limits: RLM::Limits.new(max_llm_calls: 2, max_sub_lm_calls: 0, on_budget_exceeded: :fail)
    )

    assert_equal :budget_exceeded, result.status
    assert_includes result.error.message, "max_sub_lm_calls"
    assert_equal 1, result.llm_calls
  end

  def test_max_tool_calls_blocks_tool_attempts
    lm = RLM::Lm::Mock.new(responses: [tool_code_response])

    result = RLM.predict(
      RootSignature,
      input: { text: "hello" },
      lm: lm,
      sandbox: tracking_sandbox,
      tools: [FailingTool.new],
      limits: RLM::Limits.new(max_tool_calls: 0, on_budget_exceeded: :fail)
    )

    assert_equal :budget_exceeded, result.status
    assert_includes result.error.message, "max_tool_calls"
  end

  def test_budget_policy_needs_review_returns_needs_review_without_output
    result = RLM.predict(
      RootSignature,
      input: { text: "hello" },
      lm: RLM::Lm::Mock.new(responses: ['<rlm-final>{"summary":"done"}</rlm-final>']),
      sandbox: tracking_sandbox,
      limits: RLM::Limits.new(max_llm_calls: 0, on_budget_exceeded: :needs_review)
    )

    assert_equal :needs_review, result.status
    refute result.failed?
    assert_nil result.output
  end

  def test_return_partial_uses_valid_submitted_output_as_needs_review
    lm = RLM::Lm::Mock.new(responses: [submit_then_budget_code_response])

    result = RLM.predict(
      RootSignature,
      input: { text: "hello" },
      lm: lm,
      sandbox: tracking_sandbox,
      limits: RLM::Limits.new(max_tool_calls: 0, on_budget_exceeded: :return_partial)
    )

    assert_equal :needs_review, result.status
    assert_equal({ "summary" => "partial" }, result.output)
  end

  def test_return_partial_without_valid_output_falls_back_to_budget_exceeded
    result = RLM.predict(
      RootSignature,
      input: { text: "hello" },
      lm: RLM::Lm::Mock.new(responses: ['<rlm-final>{"summary":"done"}</rlm-final>']),
      sandbox: tracking_sandbox,
      limits: RLM::Limits.new(max_llm_calls: 0, on_budget_exceeded: :return_partial)
    )

    assert_equal :budget_exceeded, result.status
    assert_nil result.output
  end

  def test_tool_error_preserves_status_and_error
    lm = RLM::Lm::Mock.new(responses: [tool_code_response])

    result = RLM.predict(
      RootSignature,
      input: { text: "hello" },
      lm: lm,
      sandbox: tracking_sandbox,
      tools: [FailingTool.new]
    )

    assert_equal :tool_error, result.status
    assert_instance_of RLM::ToolError, result.error
    assert_includes result.error.message, "tool boom"
  end

  def test_trace_store_receives_terminal_success_result
    stored = []

    result = RLM::Runtime.new(
      signature: RootSignature,
      input: { text: "hello" },
      lm: RLM::Lm::Mock.new(responses: ['<rlm-final>{"summary":"done"}</rlm-final>']),
      sandbox: tracking_sandbox,
      limits: RLM::Limits.new,
      trace_store: ->(stored_result) { stored << stored_result }
    ).call

    assert_equal :completed, result.status
    assert_equal [result], stored
    assert_equal :run_completed, stored.first.trace.events.last[:type]
  end

  def test_trace_store_receives_terminal_failure_result
    stored = []

    result = RLM::Runtime.new(
      signature: RootSignature,
      input: { text: "hello" },
      lm: RLM::Lm::Mock.new(responses: ["not a trace block"]),
      sandbox: tracking_sandbox,
      limits: RLM::Limits.new,
      trace_store: ->(stored_result) { stored << stored_result }
    ).call

    assert_equal :aborted, result.status
    assert_equal [result], stored
    assert_equal :run_failed, stored.first.trace.events.last[:type]
  end

  private

  def tracking_sandbox(exec_result: nil)
    TrackingSandbox.new(exec_result: exec_result)
  end

  def root_code_response
    <<~RESPONSE
      <rlm-code>
        sub = predict("SubSignature", { "text" => "hello" })
        submit({ "summary" => sub.fetch("summary") })
      </rlm-code>
    RESPONSE
  end

  def tool_code_response
    <<~RESPONSE
      <rlm-code>
        tool("FailingTool", {})
      </rlm-code>
    RESPONSE
  end

  def submit_then_budget_code_response
    <<~RESPONSE
      <rlm-code>
        submit({ "summary" => "partial" })
        tool("MissingTool", {})
      </rlm-code>
    RESPONSE
  end
end
# rubocop:enable Metrics/ClassLength
