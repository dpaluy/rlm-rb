# frozen_string_literal: true

require_relative "test_case"

class RLM::RuntimeBasicTest < RuntimeTestCase
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

  def test_identical_subcalls_are_cached
    root_response = <<~RESPONSE
      <rlm-code>
        first = predict("SubSignature", { "text" => "hello" })
        second = predict("SubSignature", { text: "hello" })
        submit({ "summary" => first.fetch("summary") + "/" + second.fetch("summary") })
      </rlm-code>
    RESPONSE

    result = RLM.predict(
      RootSignature,
      input: { text: "hello" },
      lm: RLM::Lm::Mock.new(responses: [root_response]),
      sub_lm: RLM::Lm::Mock.new(responses: ['<rlm-final>{"summary":"sub ok"}</rlm-final>']),
      sandbox: tracking_sandbox,
      signatures: [SubSignature],
      limits: RLM::Limits.new(max_iterations: 2, max_llm_calls: 2),
      cache: {}
    )

    assert result.success?
    assert_equal({ "summary" => "sub ok/sub ok" }, result.output)
    assert_equal 2, result.llm_calls
    sub_lm_call_count = result.trace.llm_calls.count { |event| event[:type] == :sub_lm_called }
    assert_equal 1, sub_lm_call_count
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
end
