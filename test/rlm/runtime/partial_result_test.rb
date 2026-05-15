# frozen_string_literal: true

require_relative "test_case"

class RLM::RuntimePartialResultTest < RuntimeTestCase
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
end
