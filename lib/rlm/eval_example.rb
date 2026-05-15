# frozen_string_literal: true

require "json"

module RLM
  class EvalExample
    attr_reader :id, :input, :output, :expected_output, :status, :metadata, :trace

    def self.from_result(result, expected_output: nil, metadata: {})
      new(
        input: input_from_trace(result.trace),
        output: result.output,
        expected_output: expected_output,
        status: result.status,
        metadata: result_metadata(result).merge(metadata),
        trace: result.trace
      )
    end

    def self.from_trace(trace, output: nil, expected_output: nil, status: nil, metadata: {})
      new(
        input: input_from_trace(trace),
        output: output || submitted_output_from_trace(trace),
        expected_output: expected_output,
        status: status || status_from_trace(trace),
        metadata: metadata,
        trace: trace
      )
    end

    def initialize(input:, output:, trace:, expected_output: nil, status: nil, metadata: {}, id: nil)
      @trace = trace
      @id = id || trace&.id
      @input = input
      @output = output
      @expected_output = expected_output
      @status = status
      @metadata = metadata
    end

    def to_h
      {
        id: id,
        input: input,
        output: output,
        expected_output: expected_output,
        status: status,
        metadata: metadata,
        trace: trace_payload
      }
    end

    def to_json(*)
      JSON.generate(to_h, *)
    end

    def self.input_from_trace(trace)
      trace&.events&.find { |event| event[:type] == :run_started }&.dig(:payload, :input)
    end
    private_class_method :input_from_trace

    def self.submitted_output_from_trace(trace)
      reverse_events(trace).find { |event| event[:type] == :output_submitted }&.dig(:payload, :output)
    end
    private_class_method :submitted_output_from_trace

    def self.status_from_trace(trace)
      terminal = reverse_events(trace).find { |event| %i[run_completed run_failed].include?(event[:type]) }
      terminal&.dig(:payload, :status)
    end
    private_class_method :status_from_trace

    def self.reverse_events(trace)
      trace&.events&.reverse_each || []
    end
    private_class_method :reverse_events

    def self.result_metadata(result)
      {
        cost_cents: result.cost_cents,
        duration_ms: result.duration_ms,
        llm_calls: result.llm_calls,
        iterations: result.iterations,
        validation_errors: result.validation_errors
      }
    end
    private_class_method :result_metadata

    def trace_payload
      return nil unless trace

      {
        id: trace.id,
        started_at: trace.started_at.iso8601(6),
        events: trace.events,
        llm_calls: trace.llm_calls,
        tool_calls: trace.tool_calls,
        files_read: trace.files_read,
        validation_errors: trace.validation_errors,
        cost_cents: trace.cost_cents
      }
    end
  end
end
