# frozen_string_literal: true

module RLM
  class Predict
    attr_reader :signature, :lm, :sub_lm, :tools, :skills, :sandbox,
                :limits, :trace_store, :validators, :signatures

    def initialize(
      signature,
      lm: nil,
      sub_lm: nil,
      tools: [],
      skills: [],
      sandbox: nil,
      limits: nil,
      trace_store: nil,
      validators: [],
      signatures: []
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
      @signatures = signatures
    end

    def call(input = {})
      Runtime.new(
        signature: signature,
        input: input,
        lm: lm,
        sub_lm: sub_lm,
        tools: tools,
        skills: skills,
        sandbox: sandbox,
        limits: limits,
        validators: validators,
        signatures: signatures
      ).call
    end
  end
end
