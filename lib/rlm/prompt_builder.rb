# frozen_string_literal: true

require "json"

require_relative "errors"
require_relative "file"

module RLM
  class PromptBuilder
    def self.build(signature, input:, context: nil, limits: nil)
      new(signature, input: input, context: context, limits: limits).call
    end

    def initialize(signature, input:, context: nil, limits: nil)
      raise ConfigurationError, "signature is required" if signature.nil?

      @signature = signature
      @input = input || {}
      @context = context
      @limits = limits
    end

    def call
      manifest = context_manifest
      payload_limits = limits_payload
      sections = [
        "# RLM Prediction Prompt",
        signature_section,
        input_section
      ]
      sections << context_section(manifest) if manifest
      sections << limits_section(payload_limits) if payload_limits
      sections << output_instructions_section
      sections.join("\n\n")
    end

    private

    attr_reader :signature, :input, :context, :limits

    def signature_section
      ["## Signature", signature_name].join("\n")
    end

    def input_section
      json_section("Input", input)
    end

    def context_section(manifest)
      json_section("Context Manifest", manifest)
    end

    def limits_section(payload_limits)
      json_section("Limits", payload_limits)
    end

    def output_instructions_section
      <<~PROMPT.chomp
        ## Output Instructions
        Return exactly one RLM response block and nothing else.
        Use one of these forms:
        <rlm-code>executable Ruby sandbox code</rlm-code>
        <rlm-final>{"result":"final JSON answer"}</rlm-final>
        Do not include prose, markdown fences, comments, or explanations outside the tags.
        Do not emit both block types.
        Do not emit duplicate or nested RLM tags.
        The content inside <rlm-final> must be valid JSON only.
      PROMPT
    end

    def signature_name
      name = signature.name if signature.respond_to?(:name)
      return name unless name.to_s.empty?

      signature.to_s
    end

    def context_manifest
      return nil if context.nil?
      raise ConfigurationError, "context must respond to #manifest" unless context.respond_to?(:manifest)

      manifest = context.manifest
      validate_manifest!(manifest)
      return nil if manifest[:files].empty? && manifest[:inputs].empty?

      manifest
    end

    def validate_manifest!(manifest)
      unless manifest.is_a?(Hash) && manifest.key?(:files) && manifest.key?(:inputs)
        raise ConfigurationError, "context manifest must include :files and :inputs"
      end
      raise ConfigurationError, "context manifest :files must be an Array" unless manifest[:files].is_a?(Array)
      raise ConfigurationError, "context manifest :inputs must be a Hash" unless manifest[:inputs].is_a?(Hash)
    end

    def limits_payload
      return nil if limits.nil?
      raise ConfigurationError, "limits must respond to #to_h" unless limits.respond_to?(:to_h)

      limits.to_h
    end

    def json_section(title, payload)
      ["## #{title}", JSON.pretty_generate(normalize(payload))].join("\n")
    end

    def normalize(value)
      return normalize_hash(value) if value.is_a?(Hash)
      return value.map { |item| normalize(item) } if value.is_a?(Array)
      return value.to_s if value.is_a?(Symbol)
      return normalize(value.to_h) if value.is_a?(RLM::File)

      normalize_scalar(value)
    end

    def normalize_hash(hash)
      normalized_keys = hash.keys.map(&:to_s)
      unless normalized_keys.uniq.length == normalized_keys.length
        raise ConfigurationError, "hash contains duplicate keys after string normalization"
      end

      hash.keys.sort_by(&:to_s).to_h do |key|
        [key.to_s, normalize(hash.fetch(key))]
      end
    end

    def normalize_scalar(value)
      return value if json_scalar?(value)
      return value.name || value.to_s if value.is_a?(Module)

      value.to_s
    end

    def json_scalar?(value)
      value.is_a?(String) || value.is_a?(Numeric) || value == true || value == false || value.nil?
    end
  end
end
