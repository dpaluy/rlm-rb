# frozen_string_literal: true

require "test_helper"

class RLM::Telemetry::DspyTest < Minitest::Test
  FakeContext = Struct.new(:calls) do
    def with_span(operation:, **attributes)
      calls << { operation: operation, attributes: attributes }
      yield(:span)
    end
  end

  def test_in_span_delegates_to_dspy_context
    context = FakeContext.new([])

    result = RLM::Telemetry::Dspy.new(context: context).in_span("rlm.run", attributes: { signature: "Invoice" }) do
      :ok
    end

    assert_equal :ok, result
    assert_equal "rlm.run", context.calls.first[:operation]
    assert_equal "Invoice", context.calls.first[:attributes]["rlm.signature"]
  end

  def test_in_span_works_with_real_dspy_context_when_observability_is_disabled
    result = RLM::Telemetry::Dspy.new.in_span("rlm.lm_call", attributes: { depth: 0 }) { :ok }

    assert_equal :ok, result
  end
end
