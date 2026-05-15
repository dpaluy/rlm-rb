# frozen_string_literal: true

require "json"

module RLM
  module ResponseProtocol
    module XML
      TYPES = %i[code final].freeze
      RESPONSE_PATTERN = %r{\A\s*<response\s+type="([^"]+)">\s*<content>(.*)</content>\s*</response>\s*\z}m
      CDATA_PATTERN = /\A<!\[CDATA\[(.*)\]\]>\z/m

      module_function

      def output_instructions
        <<~PROMPT.chomp
          ## Output Instructions
          Return exactly one XML document and nothing else.
          Use one of these forms:
          <response type="code"><content><![CDATA[executable Ruby sandbox code]]></content></response>
          <response type="final"><content>{"result":"final JSON answer"}</content></response>
          Do not include prose, markdown fences, comments, or explanations outside the XML document.
          The `type` attribute must be either `code` or `final`.
          The content for `final` must be valid JSON.
        PROMPT
      end

      def extract(response)
        raise ParseError, "response must be a String" unless response.is_a?(String)

        match = RESPONSE_PATTERN.match(response)
        raise ParseError, "xml response protocol requires one response content envelope" unless match

        type = parse_type(match[1])
        content = parse_text(match[2])
        { type: type, content: parse_content(type, content) }
      end

      def parse_type(raw_type)
        raise ParseError, "xml response protocol requires type" if raw_type.to_s.empty?

        type = raw_type.to_sym
        raise ParseError, "unknown xml response type: #{raw_type.inspect}" unless TYPES.include?(type)

        type
      end

      def parse_text(raw_content)
        cdata = CDATA_PATTERN.match(raw_content)
        return cdata[1] if cdata

        unescape(raw_content)
      end

      def unescape(text)
        text.gsub("&quot;", "\"")
            .gsub("&apos;", "'")
            .gsub("&lt;", "<")
            .gsub("&gt;", ">")
            .gsub("&amp;", "&")
      end

      def parse_content(type, content)
        return content if type == :code

        ::JSON.parse(content)
      rescue ::JSON::ParserError => e
        raise ParseError, "invalid JSON in xml final content: #{e.message}"
      end
    end
  end
end
