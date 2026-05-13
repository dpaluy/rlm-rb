# frozen_string_literal: true

# WARNING: This sandbox is intentionally unsafe.
#
# It executes model-produced Ruby code with instance_eval inside the current Ruby process.
# It provides no process isolation, memory isolation, filesystem isolation, network isolation,
# timeout enforcement, or protection from malicious code. Use it only in development/tests to
# prove the runtime spine. Production backends must use isolated subprocess, container, or remote
# runners instead.

require "stringio"

module RLM
  module Sandbox
    class UnsafeInProcess < Base
      attr_reader :context, :tools, :skills, :runtime_bridge

      def initialize
        super
        @prepared = false
      end

      def prepared?
        @prepared
      end

      def prepare(context:, tools:, skills:, runtime_bridge:)
        @context = context
        @tools = tools
        @skills = skills
        @runtime_bridge = runtime_bridge
        @prepared = true
        ExecutionResult.new(status: :ok)
      end

      def exec(code)
        raise SandboxError, "Sandbox not prepared" unless prepared?

        execute(code)
      end

      def execute(code)
        stdout, stderr = capture_streams do
          Scope.new(runtime_bridge).instance_eval(code, "(rlm unsafe in-process sandbox)")
        end

        ExecutionResult.new(status: :ok, stdout: stdout, stderr: stderr)
      rescue StandardError => e
        ExecutionResult.new(status: :error, stderr: e.message, error: e, exit_code: 1)
      end

      def cleanup
        @context = nil
        @tools = nil
        @skills = nil
        @runtime_bridge = nil
        @prepared = false
      end

      private

      def capture_streams
        old_stdout = $stdout
        old_stderr = $stderr
        captured_stdout = StringIO.new
        captured_stderr = StringIO.new
        $stdout = captured_stdout
        $stderr = captured_stderr
        yield
        [captured_stdout.string, captured_stderr.string]
      ensure
        $stdout = old_stdout
        $stderr = old_stderr
      end

      class Scope
        def initialize(runtime_bridge)
          @runtime_bridge = runtime_bridge
        end

        def predict(signature_name, input_hash)
          runtime_bridge.predict(signature_name, input_hash)
        end

        def tool(tool_name, input_hash)
          runtime_bridge.tool(tool_name, input_hash)
        end

        def submit(output_hash)
          runtime_bridge.submit(output_hash)
        end

        def read_file(handle)
          runtime_bridge.read_file(handle)
        end

        def list_files
          runtime_bridge.list_files
        end

        def log(message)
          runtime_bridge.log(message)
        end

        private

        attr_reader :runtime_bridge
      end
    end
  end
end
