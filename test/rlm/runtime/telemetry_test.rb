# frozen_string_literal: true

require_relative "test_case"

class RLM::RuntimeTelemetryTest < RuntimeTestCase
  SpanRecorder = Struct.new(:spans) do
    def in_span(name, attributes: {})
      spans << { name: name, attributes: attributes }
      yield
    end
  end

  def test_runtime_records_run_and_lm_call_spans
    telemetry = RLM::Telemetry.new(tracer: SpanRecorder.new([]))

    result = RLM.predict(
      RootSignature,
      input: { text: "hello" },
      lm: RLM::Lm::Mock.new(responses: ['<rlm-final>{"summary":"done"}</rlm-final>']),
      sandbox: tracking_sandbox,
      telemetry: telemetry
    )

    spans = telemetry_spans(telemetry)
    assert result.success?
    span_names = spans.map { |span| span[:name] }
    assert_equal ["rlm.run", "rlm.lm_call"], span_names
    assert_equal "RootSignature", spans.first[:attributes][:signature]
  end

  private

  def telemetry_spans(telemetry)
    telemetry.instance_variable_get(:@tracer).spans
  end
end
