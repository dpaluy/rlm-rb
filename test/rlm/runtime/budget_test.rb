# frozen_string_literal: true

require_relative "test_case"

class RLM::RuntimeBudgetTest < RuntimeTestCase
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
    sandbox = tracking_sandbox(exec_result: RLM::Sandbox::ExecutionResult.new(stdout: "x" * 11))

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
end
