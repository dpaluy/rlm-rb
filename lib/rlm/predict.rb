# frozen_string_literal: true

module RLM
  class Predict
    attr_reader :signature, :lm, :sub_lm, :tools, :skills, :sandbox,
                :limits, :trace_store, :validators

    def initialize(
      signature,
      lm: nil,
      sub_lm: nil,
      tools: [],
      skills: [],
      sandbox: nil,
      limits: nil,
      trace_store: nil,
      validators: []
    )
      raise ConfigurationError, "signature is required" if signature.nil?

      @signature = signature
      @lm = lm || RLM.config.root_lm
      @sub_lm = sub_lm || RLM.config.sub_lm
      @tools = Array(tools)
      @skills = Array(skills)
      @sandbox = sandbox || RLM.config.sandbox
      @limits = limits || RLM.config.default_limits
      @trace_store = trace_store || RLM.config.trace_store
      @validators = Array(validators)
    end

    def call(_input = {})
      raise NotImplementedError,
            "RLM::Predict#call is not implemented in v0.1.0. " \
            "The runtime loop, RubyLLM root/sub-LM adapters, and dspy.rb " \
            "signature adapter land in v0.2. The skeleton exists so that " \
            "downstream code can wire up signatures, tools, sandboxes, and " \
            "limits against a stable API."
    end
  end
end
