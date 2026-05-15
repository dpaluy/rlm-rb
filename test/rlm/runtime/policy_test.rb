# frozen_string_literal: true

require_relative "test_case"

class RLM::RuntimePolicyTest < RuntimeTestCase
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
end
