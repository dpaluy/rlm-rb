# frozen_string_literal: true

require "fileutils"

require_relative "../errors"
require_relative "context_limits"

module RLM
  module Sandbox
    class FileMounts
      def self.mount(context:, workdir:, limits:)
        new(context: context, workdir: workdir, limits: limits).mount
      end

      def initialize(context:, workdir:, limits:)
        @context = context
        @workdir = ::File.expand_path(workdir)
        @limits = limits
        @limiter = ContextLimits.new(context: context, limits: limits)
      end

      def mount
        manifest_files.each do |entry|
          file = context.file_for(entry[:handle])
          next if file.nil?

          mount_file(file, entry.fetch(:sandbox_path))
        end
      end

      private

      attr_reader :context, :workdir, :limits, :limiter

      def manifest_files
        context.manifest.fetch(:files)
      end

      def mount_file(file, sandbox_path)
        content = file.read
        limiter.validate_file_content!(file, content)
        target = expand_sandbox_path(sandbox_path)
        FileUtils.mkdir_p(::File.dirname(target))
        ::File.binwrite(target, content)
      end

      def expand_sandbox_path(sandbox_path)
        target = ::File.expand_path(sandbox_path, workdir)
        return target if target.start_with?("#{workdir}#{::File::SEPARATOR}")

        raise ConfigurationError, "sandbox_path escapes workdir: #{sandbox_path.inspect}"
      end
    end
  end
end
