# frozen_string_literal: true

require "json"

module RLM
  module ResponseProtocol
    module JSON
      TYPES = %i[code final].freeze

      module_function

      def output_instructions
        <<~PROMPT.chomp
          ## Output Instructions
          Return exactly one JSON object and nothing else.
          Use one of these forms:
          {"type":"code","content":"executable Ruby sandbox code"}
          {"type":"final","content":{"result":"final JSON answer"}}
          Do not include prose, markdown fences, comments, or explanations outside the JSON object.
          The `type` value must be either `code` or `final`.
          For `code`, `content` must be a String.
          For `final`, `content` must be any valid JSON value matching the requested output fields.
        PROMPT
      end

      def extract(response)
        raise ParseError, "response must be a String" unless response.is_a?(String)

        payload = parse_json(response)
        type = parse_type(payload)
        content = payload.fetch("content")
        raise ParseError, "json code content must be a String" if type == :code && !content.is_a?(String)

        { type: type, content: content }
      end

      def parse_json(response)
        payload = ::JSON.parse(response)
        raise ParseError, "json response protocol requires a JSON object" unless payload.is_a?(Hash)
        raise ParseError, "json response protocol requires content" unless payload.key?("content")

        payload
      rescue ::JSON::ParserError => e
        raise ParseError, "invalid JSON response: #{e.message}"
      end

      def parse_type(payload)
        raw_type = payload["type"]
        raise ParseError, "json response protocol requires type" if raw_type.nil?

        type = raw_type.to_s.to_sym
        raise ParseError, "unknown json response type: #{raw_type.inspect}" unless TYPES.include?(type)

        type
      end
    end
  end
end
