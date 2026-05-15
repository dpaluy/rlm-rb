# frozen_string_literal: true

require_relative "test_case"

class RLM::RuntimeFailureTest < RuntimeTestCase
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
end
