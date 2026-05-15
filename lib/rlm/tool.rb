# frozen_string_literal: true

module RLM
  class Tool
    CATEGORIES = %i[read_only write_requires_approval write_allowed dangerous_disabled].freeze
    FIELD_TYPES = %i[string integer float numeric boolean array hash].freeze
    TYPE_CHECKERS = {
      string: ->(value) { value.is_a?(String) },
      integer: ->(value) { value.is_a?(Integer) },
      float: ->(value) { value.is_a?(Float) },
      numeric: ->(value) { value.is_a?(Numeric) },
      boolean: ->(value) { [true, false].include?(value) },
      array: ->(value) { value.is_a?(Array) },
      hash: ->(value) { value.is_a?(Hash) }
    }.freeze

    class << self
      def description(text = nil)
        return @description if text.nil?

        @description = text
      end

      def category(value = nil)
        return @category || :read_only if value.nil?
        raise ArgumentError, "Unknown category: #{value.inspect}" unless CATEGORIES.include?(value)

        @category = value
      end

      def registry_name
        @registry_name ||= name.to_s.split("::").last
      end

      def input_schema(schema = nil)
        return @input_schema || {} if schema.nil?

        @input_schema = normalize_schema(schema)
      end

      def output_schema(schema = nil)
        return @output_schema || {} if schema.nil?

        @output_schema = normalize_schema(schema)
      end

      def validate_input(input)
        validate_schema(input_schema, input, "input")
      end

      def validate_output(output)
        validate_schema(output_schema, output, "output")
      end

      def inherited(subclass)
        super
        subclass.instance_variable_set(:@description, nil)
        subclass.instance_variable_set(:@category, nil)
        subclass.instance_variable_set(:@input_schema, nil)
        subclass.instance_variable_set(:@output_schema, nil)
      end

      private

      def normalize_schema(schema)
        schema.to_h.transform_keys(&:to_sym).tap do |normalized|
          unknown = normalized.values.map(&:to_sym) - FIELD_TYPES
          raise ArgumentError, "Unknown field type: #{unknown.first.inspect}" if unknown.any?
        end
      end

      def validate_schema(schema, payload, label)
        return [] if schema.empty?
        return ["#{label} must be a Hash"] unless payload.is_a?(Hash)

        schema.filter_map do |field, type|
          value = payload[field] || payload[field.to_s]
          next "#{label}.#{field} is required" if value.nil?
          next if value_matches_type?(value, type)

          "#{label}.#{field} must be #{type}"
        end
      end

      def value_matches_type?(value, type)
        TYPE_CHECKERS.fetch(type.to_sym).call(value)
      end
    end

    def call(**kwargs)
      raise NotImplementedError, "#{self.class} must implement #call"
    end
  end
end
