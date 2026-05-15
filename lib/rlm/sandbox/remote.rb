# frozen_string_literal: true

require_relative "context_limits"

module RLM
  module Sandbox
    class Remote < Base
      attr_reader :context, :tools, :skills, :runtime_bridge, :session_id

      def initialize(client:)
        super()
        @client = client
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
        response = request(:prepare, prepare_payload(limits))
        @session_id = response[:session_id] || response["session_id"]
        @prepared = true
        ExecutionResult.new(status: :ok)
      rescue StandardError
        cleanup
        raise
      end

      def exec(code)
        raise SandboxError, "Sandbox not prepared" unless prepared?

        result = request(:exec, session_id: session_id, code: code)
        execution_result(result)
      end

      def cleanup
        request(:cleanup, session_id: session_id) if prepared? && session_id
      ensure
        @context = nil
        @tools = nil
        @skills = nil
        @runtime_bridge = nil
        @session_id = nil
        @prepared = false
      end

      private

      attr_reader :client

      def prepare_payload(limits)
        {
          context: context.manifest,
          tools: tool_manifest,
          skills: Array(skills).map(&:manifest),
          limits: limits&.to_h
        }.compact
      end

      def tool_manifest
        return tools.manifest if tools.respond_to?(:manifest)

        Array(tools).map do |tool|
          klass = tool.is_a?(Class) ? tool : tool.class
          klass.respond_to?(:registry_name) ? tool_entry(klass) : { name: klass.name }
        end
      end

      def tool_entry(klass)
        {
          name: klass.registry_name,
          description: klass.description,
          category: klass.category,
          input_schema: klass.input_schema,
          output_schema: klass.output_schema
        }
      end

      def request(operation, payload)
        response = if client.respond_to?(operation)
                     client.public_send(operation, payload)
                   else
                     client.call(operation, payload)
                   end
        raise SandboxError, "remote sandbox returned no response" if response.nil?

        response
      end

      def execution_result(response)
        return response if response.is_a?(ExecutionResult)

        data = symbolize(response)
        error = data[:error] && RuntimeError.new(data[:error].to_s)
        ExecutionResult.new(
          stdout: data.fetch(:stdout, ""),
          stderr: data.fetch(:stderr, ""),
          exit_code: data.fetch(:exit_code, 0),
          duration_ms: data.fetch(:duration_ms, 0),
          events: data.fetch(:events, []),
          status: (data[:status] || :ok).to_sym,
          error: error
        )
      end

      def symbolize(hash)
        hash.to_h.transform_keys(&:to_sym)
      end
    end
  end
end
