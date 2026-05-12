# frozen_string_literal: true

module RLM
  module Sandbox
    class Mock < Base
      attr_reader :executed_code, :context, :tools, :skills, :runtime_bridge

      def initialize(handler: nil)
        super()
        @handler = handler
        @executed_code = []
        @prepared = false
      end

      def prepared?
        @prepared
      end

      def prepare(context:, tools:, skills:, runtime_bridge:)
        @prepared = true
        @context = context
        @tools = tools
        @skills = skills
        @runtime_bridge = runtime_bridge
        ExecutionResult.new(status: :ok)
      end

      def exec(code)
        raise SandboxError, "Sandbox not prepared" unless @prepared

        @executed_code << code
        return ExecutionResult.new(status: :ok, stdout: "") if @handler.nil?

        result = @handler.call(code, context: @context, bridge: @runtime_bridge)
        result.is_a?(ExecutionResult) ? result : ExecutionResult.new(stdout: result.to_s)
      end

      def cleanup
        @prepared = false
        @executed_code.clear
        @context = nil
        @tools = nil
        @skills = nil
        @runtime_bridge = nil
      end
    end
  end
end
