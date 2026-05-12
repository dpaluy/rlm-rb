# frozen_string_literal: true

module RLM
  module Sandbox
    class ExecutionResult
      STATUSES = %i[ok error timeout budget_exceeded].freeze

      attr_reader :stdout, :stderr, :exit_code, :duration_ms, :events, :status, :error

      def initialize(
        stdout: "",
        stderr: "",
        exit_code: 0,
        duration_ms: 0,
        events: [],
        status: :ok,
        error: nil
      )
        raise ArgumentError, "Unknown status: #{status.inspect}" unless STATUSES.include?(status)

        @stdout = stdout
        @stderr = stderr
        @exit_code = exit_code
        @duration_ms = duration_ms
        @events = events
        @status = status
        @error = error
      end

      def ok?
        status == :ok
      end

      def to_h
        {
          status: status,
          exit_code: exit_code,
          duration_ms: duration_ms,
          stdout: stdout,
          stderr: stderr,
          events: events,
          error: error&.message
        }
      end
    end
  end
end
