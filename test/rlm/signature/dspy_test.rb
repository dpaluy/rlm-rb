# frozen_string_literal: true

require "test_helper"
require "dspy"

class RLM::Signature::DspyTest < Minitest::Test
  FakeDspySignature = Class.new do
    def self.description = "Summarize text"

    def self.input_json_schema
      {
        type: "object",
        required: ["text"],
        properties: {
          text: { type: "string" },
          tone: { type: "string" }
        }
      }
    end

    def self.output_json_schema
      {
        type: "object",
        required: %w[summary score],
        properties: {
          summary: { type: "string" },
          score: { type: "integer" }
        }
      }
    end
  end

  def test_satisfies_rlm_signature_interface
    adapter = adapter_class.new(FakeDspySignature)

    assert_same adapter, RLM::Signature.validate_interface!(adapter)
  end

  def test_description_maps_from_dspy_metadata
    assert_equal "Summarize text", adapter_class.new(FakeDspySignature).description
  end

  def test_input_fields_are_derived_from_dspy_input_schema
    assert_equal({ text: :string, tone: :string }, adapter_class.new(FakeDspySignature).input_fields)
  end

  def test_output_fields_are_derived_from_dspy_output_schema
    assert_equal({ summary: :string, score: :integer }, adapter_class.new(FakeDspySignature).output_fields)
  end

  def test_valid_input_returns_empty_errors
    assert_equal [], adapter_class.new(FakeDspySignature).validate_input({ "text" => "hello" })
  end

  def test_missing_required_input_returns_stable_validation_error
    assert_equal ["text is required"], adapter_class.new(FakeDspySignature).validate_input({})
  end

  def test_invalid_typed_input_returns_stable_validation_error
    assert_equal ["text must be string"], adapter_class.new(FakeDspySignature).validate_input({ text: 123 })
  end

  def test_valid_output_returns_empty_errors
    assert_equal [], adapter_class.new(FakeDspySignature).validate_output({ "summary" => "ok", "score" => 1 })
  end

  def test_missing_required_output_returns_stable_validation_error
    assert_equal ["summary is required"], adapter_class.new(FakeDspySignature).validate_output({ "score" => 1 })
  end

  def test_invalid_typed_output_returns_stable_validation_error
    assert_equal(
      ["score must be integer"],
      adapter_class.new(FakeDspySignature).validate_output({ summary: "ok", score: "high" })
    )
  end

  def test_output_coercion_converts_string_keys_to_schema_keys_before_validation
    adapter = adapter_class.new(FakeDspySignature)

    output = adapter.coerce_output({ "summary" => "ok", "score" => 1 })

    assert_equal({ summary: "ok", score: 1 }, output)
    assert_equal [], adapter.validate_output(output)
  end

  def test_wraps_real_dspy_signature_metadata
    signature = Class.new(DSPy::Signature) do
      description "Extract a short summary"

      input do
        const :text, String
      end

      output do
        const :summary, String
        const :needs_review, T::Boolean
      end
    end

    adapter = adapter_class.new(signature)

    assert_equal "Extract a short summary", adapter.description
    assert_equal({ text: :string }, adapter.input_fields)
    assert_equal({ summary: :string, needs_review: :boolean }, adapter.output_fields)
    assert_equal [], adapter.validate_input(text: "hello")
    assert_equal [], adapter.validate_output("summary" => "short", "needs_review" => false)
    assert_equal(
      ["needs_review must be boolean"],
      adapter.validate_output("summary" => "short", "needs_review" => "false")
    )
  end

  private

  def adapter_class
    RLM::Signature::Dspy
  end
end
