# frozen_string_literal: true

require "test_helper"

class RLM::TelemetryTest < Minitest::Test
  SpanRecorder = Struct.new(:spans) do
    def in_span(name, attributes: {})
      spans << { name: name, attributes: attributes }
      yield
    end
  end

  def test_in_span_yields_without_tracer
    yielded = false

    RLM::Telemetry.new.in_span("rlm.test") { yielded = true }

    assert yielded
  end

  def test_in_span_delegates_to_tracer
    tracer = SpanRecorder.new([])

    result = RLM::Telemetry.new(tracer: tracer).in_span("rlm.test", attributes: { a: 1 }) { :ok }

    assert_equal :ok, result
    assert_equal [{ name: "rlm.test", attributes: { a: 1 } }], tracer.spans
  end
end
