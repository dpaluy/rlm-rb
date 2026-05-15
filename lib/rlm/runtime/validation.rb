# frozen_string_literal: true

module RLM
  class Runtime
    module Validation
      private

      def complete(output)
        coerced_output = Signature.coerce_output(signature, output)
        ensure_output_budget!(coerced_output)
        errors = validate_output(signature, coerced_output)
        return validation_failure(errors) unless errors.empty?

        trace.record(:run_completed, status: :completed)
        finish(:completed, output: coerced_output)
      end

      def validate_root_input!
        trace.record(:validation_attempted, signature: Signature.name_for(signature), direction: :input)
        errors = Signature.validate_input(signature, input)
        return if errors.empty?

        trace.record(:validation_failed, signature: Signature.name_for(signature), direction: :input, errors: errors)
        raise ValidationError, errors.join(", ")
      end

      def validate_output!(checked_signature, output)
        errors = validate_output(checked_signature, output)
        raise ValidationError, errors.join(", ") unless errors.empty?
      end

      def validate_output(checked_signature, output)
        trace.record(:validation_attempted, signature: Signature.name_for(checked_signature), direction: :output)
        all_errors = Signature.validate_output(checked_signature, output) + custom_validation_errors(output)
        record_validation_failure(checked_signature, all_errors) unless all_errors.empty?
        all_errors
      end

      def custom_validation_errors(output)
        validators.flat_map { |validator| Array(validator.call(output)) }
      end

      def record_validation_failure(checked_signature, errors)
        trace.record(
          :validation_failed,
          signature: Signature.name_for(checked_signature),
          direction: :output,
          errors: errors
        )
      end

      def validation_failure(errors, error = nil)
        finish(:failed_validation, validation_errors: errors, error: error)
      end
    end
  end
end
