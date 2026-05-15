# frozen_string_literal: true

module RLM
  class Runtime
    module Finish
      private

      def finish(status, output: nil, error: nil, validation_errors: [])
        record_run_failed(status, error:, validation_errors:) unless status == :completed

        result = Result.new(
          trace: trace,
          status: status,
          output: output,
          error: error,
          cost_cents: runtime_cost_cents,
          duration_ms: trace.duration_ms,
          llm_calls: llm_calls,
          iterations: iterations,
          validation_errors: validation_errors
        )
        persist_trace(result)
        result
      end

      def persist_trace(result)
        return unless trace_store.respond_to?(:call)

        trace_store.call(result)
      rescue StandardError
        nil
      end

      def record_run_failed(status, error:, validation_errors: [])
        payload = { status: status }
        payload[:error] = trace_error_payload(error) if error
        payload[:errors] = validation_errors if validation_errors.any?
        trace.record(:run_failed, payload)
      end

      def trace_error_payload(error)
        { class: error.class.name, message: error.message }
      end

      def runtime_cost_cents
        [lm, sub_lm].compact.uniq.sum do |candidate|
          candidate.respond_to?(:cost_cents) ? candidate.cost_cents : 0
        end
      end

      def cost_delta(candidate, before_cost)
        return 0 unless candidate.respond_to?(:cost_cents)

        candidate.cost_cents - before_cost.to_i
      end

      def build_context(payload)
        Context.new(inputs: payload, files: payload.values.grep(RLM::File))
      end
    end
  end
end
