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
      active_support_instrument(name, attributes) { trace_span(name, attributes, &) }
    end

    private

    attr_reader :tracer

    def active_support_instrument(name, attributes, &)
      notifications = active_support_notifications
      return yield unless notifications.respond_to?(:instrument)

      notifications.instrument(name, attributes.dup, &)
    end

    def trace_span(name, attributes, &)
      tracer = resolved_tracer
      return yield unless tracer.respond_to?(:in_span)

      tracer.in_span(name, attributes: attributes, &)
    end

    def active_support_notifications
      return nil unless defined?(::ActiveSupport)
      return nil unless ::ActiveSupport.respond_to?(:const_defined?)
      return nil unless ::ActiveSupport.const_defined?(:Notifications, false)

      ::ActiveSupport.const_get(:Notifications)
    end

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
