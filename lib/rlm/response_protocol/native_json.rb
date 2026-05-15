# frozen_string_literal: true

require "json"

module RLM
  module ResponseProtocol
    module NativeJSON
      module_function

      def output_instructions
        <<~PROMPT.chomp
          ## Output Instructions
          Return the final answer using the provider's native structured JSON response format.
          Do not return executable Ruby code.
        PROMPT
      end

      def extract(response)
        content = response.is_a?(String) ? parse_json(response) : response
        raise ParseError, "native JSON response must be a Hash" unless content.is_a?(Hash)

        { type: :final, content: content }
      end

      def native_schema(signature)
        {
          name: schema_name(signature),
          schema: object_schema(signature),
          strict: true
        }
      end

      def parse_json(response)
        ::JSON.parse(response)
      rescue ::JSON::ParserError => e
        raise ParseError, "invalid native JSON response: #{e.message}"
      end

      def object_schema(signature)
        fields = signature.output_fields
        {
          type: "object",
          properties: fields.to_h { |name, type| [name.to_s, { type: json_type(type) }] },
          required: fields.keys.map(&:to_s),
          additionalProperties: false
        }
      end

      def json_type(type)
        case type.to_sym
        when :integer then "integer"
        when :float, :number, :numeric then "number"
        when :boolean then "boolean"
        when :array then "array"
        when :hash, :object then "object"
        else "string"
        end
      end

      def schema_name(signature)
        Signature.name_for(signature).to_s.gsub(/[^a-zA-Z0-9_-]/, "_")
      end
    end
  end
end
