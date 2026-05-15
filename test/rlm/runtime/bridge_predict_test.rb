# frozen_string_literal: true

require "test_helper"
require_relative "bridge_fixtures"

class RLM::Runtime::BridgePredictTest < Minitest::Test
  include RuntimeBridgeFixtures

  def test_predict_routes_recursive_subcall_and_records_trace
    runtime = FakeRuntime.new([], nil)
    trace = RLM::Trace.new
    bridge = build_bridge(runtime: runtime, trace: trace, signatures: { "FakeSignature" => FakeSignature })

    result = bridge.predict("FakeSignature", { text: "hello" })

    assert_equal({ summary: "sub result" }, result)
    assert_equal [{ signature: FakeSignature, input: { text: "hello" }, depth: 1 }], runtime.calls
    assert_equal :validation_attempted, trace.events.last[:type]
    assert_equal "FakeSignature", trace.events.last[:payload][:signature]
  end

  def test_predict_rejects_invalid_signature_input
    trace = RLM::Trace.new
    bridge = build_bridge(trace: trace, signatures: { "FakeSignature" => FakeSignature })

    error = assert_raises(RLM::ValidationError) do
      bridge.predict("FakeSignature", {})
    end

    event_types = trace.events.map { |event| event[:type] }

    assert_includes error.message, "text is required"
    assert_equal %i[validation_attempted validation_failed], event_types
  end

  def test_predict_rejects_unknown_signature
    bridge = build_bridge(signatures: {})

    assert_raises(RLM::ValidationError) do
      bridge.predict("MissingSignature", {})
    end
  end

  def test_predict_rejects_recursive_depth_exceeded
    runtime = FakeRuntime.new([], 1)
    bridge = build_bridge(
      runtime: runtime,
      signatures: { "FakeSignature" => FakeSignature },
      depth: 2
    )

    assert_raises(RLM::BudgetExceededError) do
      bridge.predict("FakeSignature", { text: "hello" })
    end
  end
end
