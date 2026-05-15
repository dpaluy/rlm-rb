# frozen_string_literal: true

require "json"

module RLM
  class Runtime
    module Budgets
      private

      def ensure_llm_budget!
        trace.record(:budget_checked, budget: :llm_calls, current: llm_calls, limit: limits.max_llm_calls)
        raise BudgetExceededError, "max_llm_calls exceeded" if llm_calls >= limits.max_llm_calls
      end

      def ensure_sub_lm_budget!
        trace.record(:budget_checked, budget: :sub_lm_calls, current: sub_lm_calls, limit: limits.max_sub_lm_calls)
        raise BudgetExceededError, "max_sub_lm_calls exceeded" if sub_lm_calls >= limits.max_sub_lm_calls
      end

      def ensure_cost_budget!
        current_cost = runtime_cost_cents
        trace.record(:budget_checked, budget: :cost_cents, current: current_cost, limit: limits.max_cost_cents)
        raise BudgetExceededError, "max_cost_cents exceeded" if current_cost >= limits.max_cost_cents
      end

      def ensure_time_budget!
        current_ms = trace.duration_ms
        limit_ms = limits.max_runtime_seconds * 1000
        trace.record(:budget_checked, budget: :runtime_seconds, current: current_ms, limit: limit_ms)
        raise BudgetExceededError, "max_runtime_seconds exceeded" if current_ms >= limit_ms
      end

      def ensure_output_budget!(output)
        current_bytes = JSON.generate(output).bytesize
        trace.record(:budget_checked, budget: :output_bytes, current: current_bytes, limit: limits.max_output_bytes)
        raise BudgetExceededError, "max_output_bytes exceeded" if current_bytes > limits.max_output_bytes
      end

      def ensure_stdout_budget!(result)
        current_bytes = result.stdout.to_s.bytesize
        trace.record(:budget_checked, budget: :stdout_bytes, current: current_bytes, limit: limits.max_stdout_bytes)
        raise BudgetExceededError, "max_stdout_bytes exceeded" if current_bytes > limits.max_stdout_bytes
      end

      def budget_exceeded_result(error)
        case limits.on_budget_exceeded
        when :needs_review
          finish(:needs_review, output: valid_last_submitted_output, error: error)
        when :return_partial
          output = valid_last_submitted_output
          return finish(:needs_review, output: output, error: error) unless output.nil?

          finish(:budget_exceeded, error: error)
        else
          finish(:budget_exceeded, error: error)
        end
      end

      def valid_last_submitted_output
        return if @last_submitted_output.nil?
        return if validate_output(signature, @last_submitted_output).any?

        ensure_output_budget!(@last_submitted_output)
        @last_submitted_output
      rescue BudgetExceededError
        nil
      end
    end
  end
end
