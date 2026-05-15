# frozen_string_literal: true

require_relative "rlm/version"
require_relative "rlm/errors"
require_relative "rlm/response_protocol"
require_relative "rlm/code_extractor"
require_relative "rlm/signature"
require_relative "rlm/prompt_builder"
require_relative "rlm/runtime/bridge"
require_relative "rlm/lm/mock"
require_relative "rlm/lm/ruby_llm"
require_relative "rlm/limits"
require_relative "rlm/file"
require_relative "rlm/context"
require_relative "rlm/trace"
require_relative "rlm/telemetry"
require_relative "rlm/trace_store"
require_relative "rlm/trace_store/memory"
require_relative "rlm/trace_replay"
require_relative "rlm/review"
require_relative "rlm/skill"
require_relative "rlm/skills/csv"
require_relative "rlm/skills/directory"
require_relative "rlm/skills/pdf"
require_relative "rlm/skills/html"
require_relative "rlm/result"
require_relative "rlm/eval_example"
require_relative "rlm/eval_exporter"
require_relative "rlm/eval"
require_relative "rlm/optimizer/dspy_program"
require_relative "rlm/optimizer/dspy"
require_relative "rlm/signature/dspy"
require_relative "rlm/sandbox"
require_relative "rlm/sandbox/execution_result"
require_relative "rlm/sandbox/mock"
require_relative "rlm/sandbox/subprocess"
require_relative "rlm/sandbox/docker"
require_relative "rlm/sandbox/unsafe_in_process"
require_relative "rlm/runtime"
require_relative "rlm/tool"
require_relative "rlm/tool_registry"
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
