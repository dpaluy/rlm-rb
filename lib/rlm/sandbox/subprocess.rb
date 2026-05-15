# frozen_string_literal: true

require "fileutils"
require "rbconfig"
require "tmpdir"

require_relative "subprocess/runner"
require_relative "subprocess/worker_source"
require_relative "context_limits"

module RLM
  module Sandbox
    class Subprocess < Base
      DEFAULT_TIMEOUT_SECONDS = 5
      DEFAULT_STREAM_LIMIT_BYTES = 256 * 1024

      attr_reader :context, :tools, :skills, :runtime_bridge, :workdir

      def initialize(
        ruby: RbConfig.ruby,
        timeout_seconds: DEFAULT_TIMEOUT_SECONDS,
        stdout_limit_bytes: DEFAULT_STREAM_LIMIT_BYTES,
        stderr_limit_bytes: DEFAULT_STREAM_LIMIT_BYTES
      )
        super()
        @ruby = ruby
        @timeout_seconds = timeout_seconds
        @stdout_limit_bytes = stdout_limit_bytes
        @stderr_limit_bytes = stderr_limit_bytes
        @prepared = false
      end

      def prepared?
        @prepared
      end

      def prepare(context:, tools:, skills:, runtime_bridge:, limits: nil)
        ContextLimits.new(context: context, limits: limits).validate!
        @context = context
        @tools = tools
        @skills = skills
        @runtime_bridge = runtime_bridge
        @workdir = Dir.mktmpdir("rlm-subprocess-")
        @prepared = true
        ExecutionResult.new(status: :ok)
      end

      def exec(code)
        raise SandboxError, "Sandbox not prepared" unless prepared?

        script_path = ::File.join(workdir, "worker.rb")
        ::File.write(script_path, worker_source)

        Runner.new(
          ruby: @ruby,
          script_path: script_path,
          workdir: workdir,
          timeout_seconds: @timeout_seconds,
          runtime_bridge: runtime_bridge
        ).run(code)
      end

      def cleanup
        FileUtils.remove_entry(workdir) if workdir && ::File.directory?(workdir)
      ensure
        @context = nil
        @tools = nil
        @skills = nil
        @runtime_bridge = nil
        @workdir = nil
        @prepared = false
      end

      private

      def worker_source
        WorkerSource.build(
          stdout_limit_bytes: @stdout_limit_bytes,
          stderr_limit_bytes: @stderr_limit_bytes
        )
      end
    end
  end
end
