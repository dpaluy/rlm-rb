# frozen_string_literal: true

module RLM
  class Predict
    attr_reader :signature, :lm, :sub_lm, :tools, :skills, :sandbox,
                :limits, :trace_store, :tool_authorizer, :cache, :telemetry, :validators, :signatures

    def initialize(
      signature,
      lm: nil,
      sub_lm: nil,
      tools: [],
      skills: [],
      sandbox: nil,
      limits: nil,
      trace_store: nil,
      tool_authorizer: nil,
      cache: nil,
      telemetry: nil,
      validators: [],
      signatures: []
    )
      raise ConfigurationError, "signature is required" if signature.nil?

      @signature = signature
      @lm = lm || RLM.config.root_lm
      @sub_lm = sub_lm || RLM.config.sub_lm
      @tools = normalize_tools(tools)
      @skills = Array(skills)
      @sandbox = sandbox || RLM.config.sandbox
      @limits = limits || RLM.config.default_limits
      @trace_store = trace_store || RLM.config.trace_store
      @tool_authorizer = resolve_tool_authorizer(tool_authorizer)
      @cache = resolve_cache(cache)
      @telemetry = resolve_telemetry(telemetry)
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
        signatures: signatures,
        trace_store: trace_store,
        tool_authorizer: tool_authorizer,
        cache: cache,
        telemetry: telemetry
      ).call
    end

    private

    def normalize_tools(candidate)
      candidate.is_a?(ToolRegistry) ? candidate : Array(candidate)
    end

    def resolve_tool_authorizer(candidate)
      return candidate unless candidate.nil?

      RLM.config.tool_authorizer
    end

    def resolve_cache(candidate)
      return candidate unless candidate.nil?

      RLM.config.cache
    end

    def resolve_telemetry(candidate)
      return candidate unless candidate.nil?

      RLM.config.telemetry
    end
  end
end
