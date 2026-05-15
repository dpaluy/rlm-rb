# frozen_string_literal: true

require "json"

require_relative "../errors"
require_relative "../limits"

module RLM
  module Sandbox
    class ContextLimits
      def initialize(context:, limits:)
        @context = context
        @limits = limits || Limits.new
      end

      def validate!
        enforce_file_count!
        enforce_declared_file_sizes!
        enforce_input_size!
      end

      def validate_file_content!(file, content)
        return if bytesize(content) <= limits.max_file_bytes

        raise BudgetExceededError,
              "max_file_bytes exceeded for #{file.filename}: #{bytesize(content)} > #{limits.max_file_bytes}"
      end

      private

      attr_reader :context, :limits

      def enforce_file_count!
        return if context.files.length <= limits.max_files

        raise BudgetExceededError, "max_files exceeded: #{context.files.length} > #{limits.max_files}"
      end

      def enforce_declared_file_sizes!
        context.files.each do |file|
          next if file.size_bytes <= limits.max_file_bytes

          raise BudgetExceededError,
                "max_file_bytes exceeded for #{file.filename}: #{file.size_bytes} > #{limits.max_file_bytes}"
        end
      end

      def enforce_input_size!
        input_bytes = JSON.generate(context.manifest[:inputs]).bytesize
        return if input_bytes <= limits.max_input_bytes

        raise BudgetExceededError, "max_input_bytes exceeded: #{input_bytes} > #{limits.max_input_bytes}"
      end

      def bytesize(value)
        value.to_s.bytesize
      end
    end
  end
end
