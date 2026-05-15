# frozen_string_literal: true

require_relative "errors"
require_relative "response_protocol/tags"
require_relative "response_protocol/json"
require_relative "response_protocol/xml"
require_relative "response_protocol/native_json"
require_relative "response_protocol/selection"

module RLM
  module ResponseProtocol
    DEFAULT = Tags
    TYPES = Tags::TYPES
    CODE_OPEN = Tags::CODE_OPEN
    CODE_CLOSE = Tags::CODE_CLOSE
    FINAL_OPEN = Tags::FINAL_OPEN
    FINAL_CLOSE = Tags::FINAL_CLOSE
    KNOWN_TAG_PATTERN = Tags::KNOWN_TAG_PATTERN

    module_function

    def tags_for(type)
      Tags.tags_for(type)
    end

    def output_instructions
      DEFAULT.output_instructions
    end

    def extract(response)
      DEFAULT.extract(response)
    end

    def optimize(...)
      SelectionOptimizer.optimize(...)
    end
  end
end
