# frozen_string_literal: true

module RLM
  module Signature
    class Dspy
      TYPE_MAP = {
        "array" => :array,
        "boolean" => :boolean,
        "integer" => :integer,
        "number" => :number,
        "object" => :object,
        "string" => :string
      }.freeze

      def initialize(signature)
        @signature = signature
      end

      def name
        return signature.name if signature.respond_to?(:name) && !signature.name.to_s.empty?

        signature.to_s
      end

      def description
        return signature.description if signature.respond_to?(:description)

        name
      end

      def input_fields = fields_for(input_schema)

      def output_fields = fields_for(output_schema)

      def validate_input(input) = validate_payload(input, input_schema)

      def validate_output(output) = validate_payload(output, output_schema)

      def coerce_output(output)
        return output unless output.is_a?(Hash)

        schema_keys = output_fields.keys
        output.each_with_object({}) do |(key, value), coerced|
          coerced_key = schema_keys.find { |schema_key| schema_key.to_s == key.to_s } || key
          coerced[coerced_key] = value
        end
      end

      private

      attr_reader :signature

      def input_schema
        schema_from(:input_json_schema, :input_schema)
      end

      def output_schema
        schema_from(:output_json_schema, :output_schema)
      end

      def schema_from(*method_names)
        method_names.each do |method_name|
          next unless signature.respond_to?(method_name)

          schema = signature.public_send(method_name)
          return normalize_hash(schema) if schema.is_a?(Hash)
        end
        raise ConfigurationError, "dspy signature #{name} does not expose JSON schema metadata"
      end

      def fields_for(schema)
        properties_for(schema).each_with_object({}) do |(field_name, metadata), fields|
          fields[field_name.to_sym] = field_type(metadata)
        end
      end

      def validate_payload(payload, schema)
        return ["payload must be a Hash"] unless payload.is_a?(Hash)

        normalized = normalize_hash(payload)
        required_errors(schema, normalized) + type_errors(schema, normalized)
      end

      def required_errors(schema, payload)
        required_fields(schema).filter_map do |field_name|
          "#{field_name} is required" unless payload.key?(field_name.to_s) || payload.key?(field_name.to_sym)
        end
      end

      def type_errors(schema, payload)
        properties_for(schema).filter_map do |field_name, metadata|
          value = fetch_payload_value(payload, field_name)
          next if value.nil? || value_matches_type?(value, field_type(metadata))

          "#{field_name} must be #{field_type(metadata)}"
        end
      end

      def fetch_payload_value(payload, field_name)
        payload.fetch(field_name.to_s) { payload[field_name.to_sym] }
      end

      def required_fields(schema)
        Array(schema["required"] || schema[:required]).map(&:to_s)
      end

      def properties_for(schema)
        normalize_hash(schema["properties"] || schema[:properties] || {})
      end

      def field_type(metadata)
        normalized = normalize_hash(metadata || {})
        type = normalized["type"] || normalized[:type]
        TYPE_MAP.fetch(type.to_s, type.to_s.empty? ? :object : type.to_s.to_sym)
      end

      def value_matches_type?(value, type)
        case type
        when :array
          value.is_a?(Array)
        when :boolean
          boolean?(value)
        when :integer
          value.is_a?(Integer)
        when :number
          value.is_a?(Numeric)
        when :object
          value.is_a?(Hash)
        when :string
          value.is_a?(String)
        else true
        end
      end

      def boolean?(value)
        [true, false].include?(value)
      end

      def normalize_hash(hash)
        hash.each_with_object({}) do |(key, value), normalized|
          normalized[key] = value.is_a?(Hash) ? normalize_hash(value) : value
        end
      end
    end
  end
end
