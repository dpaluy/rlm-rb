# frozen_string_literal: true

module RLM
  class Result
    STATUSES = %i[
      completed
      needs_review
      failed_validation
      budget_exceeded
      sandbox_error
      tool_error
      provider_error
      aborted
    ].freeze

    FAILURE_STATUSES = %i[
      failed_validation
      budget_exceeded
      sandbox_error
      tool_error
      provider_error
      aborted
    ].freeze

    attr_reader :output, :trace, :status, :error, :cost_cents,
                :duration_ms, :llm_calls, :iterations, :validation_errors

    def initialize(
      trace:,
      status:,
      output: nil,
      error: nil,
      cost_cents: 0,
      duration_ms: 0,
      llm_calls: 0,
      iterations: 0,
      validation_errors: []
    )
      raise ArgumentError, "Unknown status: #{status.inspect}" unless STATUSES.include?(status)

      @output = output
      @trace = trace
      @status = status
      @error = error
      @cost_cents = cost_cents
      @duration_ms = duration_ms
      @llm_calls = llm_calls
      @iterations = iterations
      @validation_errors = validation_errors
    end

    def success?
      status == :completed
    end

    def needs_review?
      status == :needs_review
    end

    def failed?
      FAILURE_STATUSES.include?(status)
    end

    def to_h
      {
        output: output,
        status: status,
        error: error&.message,
        cost_cents: cost_cents,
        duration_ms: duration_ms,
        llm_calls: llm_calls,
        iterations: iterations,
        validation_errors: validation_errors,
        trace_id: trace&.id
      }
    end
  end
end
