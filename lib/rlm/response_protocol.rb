# frozen_string_literal: true

require_relative "errors"

module RLM
  module ResponseProtocol
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
  end
end
