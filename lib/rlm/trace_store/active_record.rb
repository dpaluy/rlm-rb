# frozen_string_literal: true

require_relative "../trace_store"

module RLM
  class TraceStore
    class ActiveRecord < TraceStore
      def initialize(record_class:)
        super()
        @record_class = record_class
      end

      def store(result)
        trace_id = result.trace&.id
        raise ArgumentError, "result must have a trace id" if trace_id.nil?

        record_class.create!(attributes_for(result, trace_id))
      end

      def fetch(trace_id)
        record_class.find_by(trace_id: trace_id)
      end

      private

      attr_reader :record_class

      def attributes_for(result, trace_id)
        {
          trace_id: trace_id,
          status: result.status.to_s,
          output: result.output,
          error_message: result.error&.message,
          cost_cents: result.cost_cents,
          duration_ms: result.duration_ms,
          llm_calls: result.llm_calls,
          iterations: result.iterations,
          validation_errors: result.validation_errors,
          trace: result.trace&.to_h
        }
      end
    end
  end
end
