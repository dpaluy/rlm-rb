# frozen_string_literal: true

require "json"

module RLM
  module ResponseProtocol
    module Tags
      CODE_OPEN = "<rlm-code>"
      CODE_CLOSE = "</rlm-code>"
      FINAL_OPEN = "<rlm-final>"
      FINAL_CLOSE = "</rlm-final>"
      KNOWN_TAG_PATTERN = %r{</?rlm-(?:code|final)>}
      TYPES = %i[code final].freeze

      module_function

      def tags_for(type)
        case type
        when :code then [CODE_OPEN, CODE_CLOSE]
        when :final then [FINAL_OPEN, FINAL_CLOSE]
        else raise ParseError, "unknown block type: #{type.inspect}"
        end
      end

      def output_instructions
        <<~PROMPT.chomp
          ## Output Instructions
          Return exactly one RLM response block and nothing else.
          Use one of these forms:
          #{CODE_OPEN}executable Ruby sandbox code#{CODE_CLOSE}
          #{FINAL_OPEN}{"result":"final JSON answer"}#{FINAL_CLOSE}
          Do not include prose, markdown fences, comments, or explanations outside the tags.
          Do not emit both block types.
          Do not emit duplicate or nested RLM tags.
          The content inside #{FINAL_OPEN} must be valid JSON only.
        PROMPT
      end

      def extract(response)
        raise ParseError, "response must be a String" unless response.is_a?(String)

        tags = scan_tags(response)
        raise ParseError, "response must contain one rlm-code or rlm-final block" if tags.empty?

        type = block_type_for(tags)
        block = extract_block(response, tags, type)
        { type: type, content: parse_content(type, block) }
      end

      def extract_block(response, tags, type)
        open_tag, close_tag = tags_for(type)
        opening, closing = matching_tags(tags, open_tag, close_tag)
        raise ParseError, "#{close_tag} must appear after #{open_tag}" if closing[:begin] < opening[:end]

        reject_non_whitespace_outside_block!(response, opening, closing)
        content = response[opening[:end]...closing[:begin]]
        reject_nested_tags!(content)
        content
      end

      def matching_tags(tags, open_tag, close_tag)
        open_tags = tags.select { |tag| tag[:text] == open_tag }
        close_tags = tags.select { |tag| tag[:text] == close_tag }

        raise ParseError, "response must contain exactly one #{open_tag} tag" unless open_tags.one?
        raise ParseError, "response must contain exactly one #{close_tag} tag" unless close_tags.one?

        [open_tags.first, close_tags.first]
      end

      def scan_tags(response)
        response.to_enum(:scan, KNOWN_TAG_PATTERN).map do
          match = Regexp.last_match
          { text: match[0], begin: match.begin(0), end: match.end(0) }
        end
      end

      def block_type_for(tags)
        has_code = tags.any? { |tag| code_tags.include?(tag[:text]) }
        has_final = tags.any? { |tag| final_tags.include?(tag[:text]) }

        raise ParseError, "response must not mix rlm-code and rlm-final blocks" if has_code && has_final

        has_code ? :code : :final
      end

      def reject_non_whitespace_outside_block!(response, opening, closing)
        before = response[0...opening[:begin]]
        after = response[closing[:end]..]
        return if before.match?(/\A\s*\z/) && after.match?(/\A\s*\z/)

        raise ParseError, "response must contain only one rlm block and surrounding whitespace"
      end

      def reject_nested_tags!(content)
        return unless content.match?(KNOWN_TAG_PATTERN)

        raise ParseError, "rlm blocks must not contain nested rlm tags"
      end

      def parse_content(type, content)
        return content if type == :code

        ::JSON.parse(content)
      rescue ::JSON::ParserError => e
        raise ParseError, "invalid JSON in rlm-final block: #{e.message}"
      end

      def code_tags = tags_for(:code)

      def final_tags = tags_for(:final)
    end
  end
end
