# frozen_string_literal: true

require "test_helper"

class RLM::SignatureTest < Minitest::Test
  ValidSignature = Class.new do
    def self.description
      "Extract a total"
    end

    def self.input_fields
      { text: :string }
    end

    def self.output_fields
      { total: :integer }
    end

    def self.validate_input(input)
      input.key?(:text) || input.key?("text") ? [] : ["text is required"]
    end

    def self.validate_output(output)
      output.key?(:total) || output.key?("total") ? [] : ["total is required"]
    end
  end

  def test_validate_interface_accepts_protocol_class
    assert_same ValidSignature, RLM::Signature.validate_interface!(ValidSignature)
  end

  def test_validate_interface_rejects_missing_methods
    error = assert_raises(RLM::ConfigurationError) do
      RLM::Signature.validate_interface!(Class.new)
    end

    assert_includes error.message, "description"
  end

  def test_validate_interface_requires_field_hashes
    signature = Class.new(ValidSignature) do
      def self.input_fields
        [:text]
      end
    end

    assert_raises(RLM::ConfigurationError) do
      RLM::Signature.validate_interface!(signature)
    end
  end

  def test_validate_input_returns_signature_errors
    assert_equal ["text is required"], RLM::Signature.validate_input(ValidSignature, {})
  end

  def test_validate_input_rejects_non_array_errors
    signature = Class.new(ValidSignature) do
      def self.validate_input(_input)
        "bad"
      end
    end

    assert_raises(RLM::ConfigurationError) do
      RLM::Signature.validate_input(signature, {})
    end
  end

  def test_assert_valid_input_raises_validation_error
    error = assert_raises(RLM::ValidationError) do
      RLM::Signature.assert_valid_input!(ValidSignature, {})
    end

    assert_includes error.message, "text is required"
  end

  def test_assert_valid_output_raises_validation_error
    error = assert_raises(RLM::ValidationError) do
      RLM::Signature.assert_valid_output!(ValidSignature, {})
    end

    assert_includes error.message, "total is required"
  end

  def test_name_for_prefers_class_name
    signature = Class.new(ValidSignature)
    signature.define_singleton_method(:name) { "InvoiceSignature" }

    assert_equal "InvoiceSignature", RLM::Signature.name_for(signature)
  end
end
