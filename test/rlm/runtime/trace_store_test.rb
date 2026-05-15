# frozen_string_literal: true

require_relative "test_case"

class RLM::RuntimeTraceStoreTest < RuntimeTestCase
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
end
