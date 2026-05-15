# frozen_string_literal: true

require "json"

require_relative "../errors"
require_relative "../file"

module RLM
  class PromptBuilder
    class PayloadSections
      def initialize(context:, limits:)
        @context = context
        @limits = limits
      end

      def json_section(title, payload)
        ["## #{title}", json_payload(payload)].join("\n")
      end

      def json_payload(payload)
        JSON.pretty_generate(normalize(payload))
      end

      def context_manifest
        return nil if context.nil?
        raise ConfigurationError, "context must respond to #manifest" unless context.respond_to?(:manifest)

        manifest = context.manifest
        validate_manifest!(manifest)
        return nil if manifest[:files].empty? && manifest[:inputs].empty?

        manifest
      end

      def limits_payload
        return nil if limits.nil?
        raise ConfigurationError, "limits must respond to #to_h" unless limits.respond_to?(:to_h)

        limits.to_h
      end

      private

      attr_reader :context, :limits

      def validate_manifest!(manifest)
        unless manifest.is_a?(Hash) && manifest.key?(:files) && manifest.key?(:inputs)
          raise ConfigurationError, "context manifest must include :files and :inputs"
        end
        raise ConfigurationError, "context manifest :files must be an Array" unless manifest[:files].is_a?(Array)
        raise ConfigurationError, "context manifest :inputs must be a Hash" unless manifest[:inputs].is_a?(Hash)
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
end
