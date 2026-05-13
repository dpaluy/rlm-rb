# frozen_string_literal: true

require_relative "errors"

module RLM
  module Signature
    REQUIRED_METHODS = %i[
      description
      input_fields
      output_fields
      validate_input
      validate_output
    ].freeze

    module_function

    def validate_interface!(signature)
      missing = REQUIRED_METHODS.reject { |method_name| signature.respond_to?(method_name) }
      raise ConfigurationError, "signature is missing required methods: #{missing.join(", ")}" unless missing.empty?

      validate_fields!(signature, :input_fields)
      validate_fields!(signature, :output_fields)
      signature
    end

    def validate_input(signature, input)
      validate_payload(signature, input, :validate_input)
    end

    def validate_output(signature, output)
      validate_payload(signature, output, :validate_output)
    end

    def assert_valid_input!(signature, input)
      errors = validate_input(signature, input)
      raise ValidationError, errors.join(", ") unless errors.empty?

      nil
    end

    def assert_valid_output!(signature, output)
      errors = validate_output(signature, output)
      raise ValidationError, errors.join(", ") unless errors.empty?

      nil
    end

    def name_for(signature)
      name = signature.name if signature.respond_to?(:name)
      return name unless name.to_s.empty?

      signature.to_s
    end

    def validate_fields!(signature, method_name)
      fields = signature.public_send(method_name)
      return if fields.is_a?(Hash)

      raise ConfigurationError, "signature .#{method_name} must return a Hash"
    end

    def validate_payload(signature, payload, method_name)
      validate_interface!(signature)
      errors = signature.public_send(method_name, payload)
      return errors if errors.is_a?(Array)

      raise ConfigurationError, "signature .#{method_name} must return an Array"
    end
  end
end
