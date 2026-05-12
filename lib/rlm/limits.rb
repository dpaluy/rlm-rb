# frozen_string_literal: true

module RLM
  class Limits
    INTEGER_DEFAULTS = {
      max_iterations: 8,
      max_llm_calls: 25,
      max_sub_lm_calls: 20,
      max_tool_calls: 20,
      max_runtime_seconds: 120,
      max_cost_cents: 100,
      max_input_bytes: 25 * 1024 * 1024,
      max_output_bytes: 1 * 1024 * 1024,
      max_stdout_bytes: 256 * 1024,
      max_files: 50,
      max_file_bytes: 25 * 1024 * 1024,
      max_recursion_depth: 1
    }.freeze

    BUDGET_POLICIES = %i[fail return_partial needs_review].freeze
    DEFAULT_POLICY = :needs_review

    DEFAULTS = INTEGER_DEFAULTS.merge(on_budget_exceeded: DEFAULT_POLICY).freeze

    attr_reader(*DEFAULTS.keys)

    def initialize(**overrides)
      unknown = overrides.keys - DEFAULTS.keys
      raise ArgumentError, "Unknown limit keys: #{unknown.join(", ")}" if unknown.any?

      DEFAULTS.merge(overrides).each do |key, value|
        instance_variable_set("@#{key}", value)
      end
      validate!
    end

    def merge(**overrides)
      self.class.new(**to_h, **overrides)
    end

    def to_h
      DEFAULTS.keys.to_h { |k| [k, public_send(k)] }
    end

    private

    def validate!
      INTEGER_DEFAULTS.each_key do |key|
        value = public_send(key)
        next if value.is_a?(Integer) && value >= 0

        raise ArgumentError, "#{key} must be a non-negative integer, got #{value.inspect}"
      end

      return if BUDGET_POLICIES.include?(on_budget_exceeded)

      raise ArgumentError,
            "on_budget_exceeded must be one of #{BUDGET_POLICIES.inspect}, got #{on_budget_exceeded.inspect}"
    end
  end
end
