# frozen_string_literal: true

module RLM
  module Sandbox
    class Subprocess < Base
      class ResultBuilder
        def initialize(message:, worker_stderr:, exit_code:, started:)
          @message = message
          @worker_stderr = worker_stderr
          @exit_code = exit_code
          @started = started
        end

        def build
          ExecutionResult.new(
            status: message["status"].to_sym,
            stdout: message["stdout"].to_s,
            stderr: stderr_text,
            exit_code: exit_code,
            duration_ms: duration_ms,
            error: error
          )
        end

        private

        attr_reader :message, :worker_stderr, :exit_code, :started

        def stderr_text
          [message["stderr"], worker_stderr].compact.join
        end

        def error
          return unless message["error_class"] || message["message"]

          error_class = constantize_error(message["error_class"])
          error_class.new(message["message"].to_s)
        end

        def constantize_error(class_name)
          return RuntimeError if class_name.to_s.empty?

          class_name.split("::").inject(Object) { |scope, name| scope.const_get(name) }
        rescue NameError
          RuntimeError
        end

        def duration_ms
          ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round
        end
      end
    end
  end
end
