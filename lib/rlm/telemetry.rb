# frozen_string_literal: true

module RLM
  class Telemetry
    def initialize(tracer: nil)
      @tracer = tracer
    end

    def self.default
      new
    end

    def in_span(name, attributes: {}, &)
      tracer = resolved_tracer
      return yield unless tracer.respond_to?(:in_span)

      tracer.in_span(name, attributes: attributes, &)
    end

    private

    attr_reader :tracer

    def resolved_tracer
      tracer || open_telemetry_tracer
    end

    def open_telemetry_tracer
      return nil unless defined?(::OpenTelemetry)
      return nil unless ::OpenTelemetry.respond_to?(:tracer_provider)

      ::OpenTelemetry.tracer_provider.tracer("rlm-rb")
    rescue StandardError
      nil
    end
  end
end
