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
      limits: RLM::Limits.new(max_iterations: 2, max_llm_calls: 1)
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

  def test_budget_exhaustion_at_llm_budget_cleans_up_sandbox
    lm = RLM::Lm::Mock.new(responses: ['<rlm-final>{"summary":"done"}</rlm-final>'])
    sandbox = tracking_sandbox

    result = RLM.predict(
      RootSignature,
      input: { text: "hello" },
      lm: lm,
      sandbox: sandbox,
      limits: RLM::Limits.new(max_llm_calls: 0)
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
      limits: RLM::Limits.new(max_cost_cents: 100)
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
      limits: RLM::Limits.new(max_output_bytes: 10)
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
      limits: RLM::Limits.new(max_stdout_bytes: 10)
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
      limits: RLM::Limits.new(max_runtime_seconds: 0),
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
end
