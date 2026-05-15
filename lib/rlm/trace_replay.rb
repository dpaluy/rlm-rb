# frozen_string_literal: true

module RLM
  class TraceReplay
    ReplayError = Struct.new(:error_class, :message, keyword_init: true) do
      def to_s = message.to_s
    end

    def self.result(trace)
      new(trace).result
    end

    def initialize(trace)
      @trace = trace
    end

    def result
      Result.new(
        trace: trace,
        status: terminal_status,
        output: terminal_output,
        error: terminal_error,
        cost_cents: trace.cost_cents,
        duration_ms: trace.duration_ms,
        llm_calls: trace.llm_calls.size,
        iterations: trace.steps.count { |event| event[:type] == :code_generated },
        validation_errors: validation_errors
      )
    end

    private

    attr_reader :trace

    def terminal_event
      @terminal_event ||= trace.events.reverse_each.find do |event|
        %i[run_completed run_failed].include?(event[:type])
      end
    end

    def terminal_payload
      terminal_event&.fetch(:payload, {}) || {}
    end

    def terminal_status
      status = terminal_payload[:status]
      raise ArgumentError, "trace has no terminal status" if status.nil?

      status
    end

    def terminal_output
      terminal_payload[:output] || last_submitted_output
    end

    def last_submitted_output
      trace.events.reverse_each.find { |event| event[:type] == :output_submitted }&.dig(:payload, :output)
    end

    def terminal_error
      payload = terminal_payload[:error]
      return nil unless payload

      ReplayError.new(error_class: payload[:class], message: payload[:message])
    end

    def validation_errors
      terminal_payload[:errors] || trace.validation_errors.flat_map { |event| Array(event.dig(:payload, :errors)) }
    end
  end
end
