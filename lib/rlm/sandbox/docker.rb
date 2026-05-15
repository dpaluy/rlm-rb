# frozen_string_literal: true

require "fileutils"
require "tmpdir"

require_relative "context_limits"
require_relative "docker/runner"
require_relative "file_mounts"
require_relative "subprocess/worker_source"

module RLM
  module Sandbox
    class Docker < Base
      DEFAULT_IMAGE = "ruby:3.3"
      DEFAULT_TIMEOUT_SECONDS = 5
      DEFAULT_STREAM_LIMIT_BYTES = 256 * 1024
      CONTAINER_WORKDIR = "/workspace"

      attr_reader :context, :tools, :skills, :runtime_bridge, :workdir

      def initialize(
        image: DEFAULT_IMAGE,
        docker: "docker",
        timeout_seconds: DEFAULT_TIMEOUT_SECONDS,
        stdout_limit_bytes: DEFAULT_STREAM_LIMIT_BYTES,
        stderr_limit_bytes: DEFAULT_STREAM_LIMIT_BYTES
      )
        super()
        @image = image
        @docker = docker
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
        @workdir = Dir.mktmpdir("rlm-docker-")
        FileMounts.mount(context: context, workdir: workdir, limits: limits)
        @prepared = true
        ExecutionResult.new(status: :ok)
      rescue StandardError
        cleanup
        raise
      end

      def exec(code)
        raise SandboxError, "Sandbox not prepared" unless prepared?

        ::File.write(::File.join(workdir, "worker.rb"), worker_source)
        runner.run(code)
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

      attr_reader :image, :docker, :timeout_seconds

      def runner
        Runner.new(
          docker: docker,
          image: image,
          workdir: workdir,
          container_workdir: CONTAINER_WORKDIR,
          timeout_seconds: timeout_seconds,
          runtime_bridge: runtime_bridge
        )
      end

      def worker_source
        Subprocess::WorkerSource.build(
          stdout_limit_bytes: @stdout_limit_bytes,
          stderr_limit_bytes: @stderr_limit_bytes
        )
      end
    end
  end
end
