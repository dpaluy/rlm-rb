# frozen_string_literal: true

require_relative "rlm/version"
require_relative "rlm/errors"
require_relative "rlm/code_extractor"
require_relative "rlm/lm/mock"
require_relative "rlm/limits"
require_relative "rlm/file"
require_relative "rlm/context"
require_relative "rlm/trace"
require_relative "rlm/result"
require_relative "rlm/sandbox"
require_relative "rlm/sandbox/execution_result"
require_relative "rlm/sandbox/mock"
require_relative "rlm/tool"
require_relative "rlm/config"
require_relative "rlm/predict"

module RLM
  class << self
    def config
      @config ||= Config.new
    end

    def configure
      yield config
    end

    def reset_configuration!
      @config = nil
    end

    def predict(signature, input:, **)
      Predict.new(signature, **).call(input)
    end
  end
end
