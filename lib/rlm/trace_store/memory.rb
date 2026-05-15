# frozen_string_literal: true

require_relative "../trace_store"

module RLM
  class TraceStore
    class Memory < TraceStore
      def initialize
        super
        @results = {}
      end

      def store(result)
        key = trace_id_for(result)
        raise ArgumentError, "result must have a trace id" if key.nil?

        results[key] = result
      end

      def fetch(trace_id)
        results[trace_id]
      end

      def all
        results.values
      end

      def clear
        results.clear
      end

      private

      attr_reader :results

      def trace_id_for(result)
        result.respond_to?(:trace) ? result.trace&.id : nil
      end
    end
  end
end
