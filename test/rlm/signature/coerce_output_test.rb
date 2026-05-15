# frozen_string_literal: true

require "test_helper"

class RLM::SignatureCoerceOutputTest < Minitest::Test
  PlainSignature = Class.new do
    def self.description = "Plain signature"
    def self.input_fields = { text: :string }
    def self.output_fields = { summary: :string }
    def self.validate_input(_input) = []
    def self.validate_output(_output) = []
  end

  CoercingSignature = Class.new(PlainSignature) do
    def self.coerce_output(output)
      { "summary" => output.fetch("summary").upcase }
    end
  end

  def test_defaults_to_identity_for_current_protocol_signatures
    output = { "summary" => "done" }

    assert_same output, RLM::Signature.coerce_output(PlainSignature, output)
  end

  def test_delegates_to_signature_coercion_when_present
    output = RLM::Signature.coerce_output(CoercingSignature, { "summary" => "done" })

    assert_equal({ "summary" => "DONE" }, output)
  end
end
