# frozen_string_literal: true

require_relative "../errors"

module RLM
  module ResponseProtocol
    class BAML
      def initialize(adapter:)
        @adapter = adapter
      end

      def output_instructions
        return adapter.output_instructions if adapter.respond_to?(:output_instructions)
        return adapter.instructions if adapter.respond_to?(:instructions)

        <<~PROMPT.chomp
          ## Output Instructions
          Return output using the configured BAML response format.
          The host application's BAML adapter will parse the model response into either code or final JSON content.
        PROMPT
      end

      def extract(response)
        normalize(adapter_response(response))
      end

      private

      attr_reader :adapter

      def adapter_response(response)
        return adapter.extract(response) if adapter.respond_to?(:extract)
        return adapter.parse(response) if adapter.respond_to?(:parse)

        raise ParseError, "BAML response protocol adapter must respond to #extract or #parse"
      end

      def normalize(value)
        type = value_for(value, :type)
        content = value_for(value, :content)
        raise ParseError, "BAML response protocol requires type" if type.nil?
        raise ParseError, "BAML response protocol requires content" if content.nil?

        { type: normalize_type(type), content: content }
      end

      def normalize_type(type)
        normalized = type.to_sym
        return normalized if TYPES.include?(normalized)

        raise ParseError, "unknown BAML response type: #{type.inspect}"
      end

      def value_for(value, key)
        return value.public_send(key) if value.respond_to?(key)
        return value[key] if value.respond_to?(:key?) && value.key?(key)

        string_key = key.to_s
        value[string_key] if value.respond_to?(:key?) && value.key?(string_key)
      end
    end
  end
end
