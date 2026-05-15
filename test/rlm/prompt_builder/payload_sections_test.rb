# frozen_string_literal: true

require "test_helper"

class RLM::PromptBuilder::PayloadSectionsTest < Minitest::Test
  def test_prompt_includes_context_manifest_when_context_has_files_or_inputs
    file = RLM::File.from_text("invoice.txt", "total: 10")
    context = RLM::Context.new(inputs: { invoice: file, vendor_id: 7 }, files: [file])

    prompt = RLM::PromptBuilder.build("ExtractTotal", input: {}, context: context)

    assert_includes prompt, "## Context Manifest"
    assert_includes prompt, "file_1"
    assert_includes prompt, "invoice.txt"
    assert_includes prompt, "rlm_files/file_1/invoice.txt"
    assert_includes prompt, '"vendor_id": 7'
    assert_includes prompt, '"file_handle": "file_1"'
  end

  def test_prompt_omits_context_manifest_when_context_is_nil
    prompt = RLM::PromptBuilder.build("NoContext", input: {})

    refute_includes prompt, "## Context Manifest"
  end

  def test_prompt_omits_context_manifest_when_context_is_empty
    context = RLM::Context.new

    prompt = RLM::PromptBuilder.build("EmptyContext", input: {}, context: context)

    refute_includes prompt, "## Context Manifest"
  end

  def test_prompt_includes_limits_when_provided
    limits = RLM::Limits.new(max_iterations: 2)

    prompt = RLM::PromptBuilder.build("Limited", input: {}, limits: limits)

    assert_includes prompt, "## Limits"
    assert_includes prompt, '"max_iterations": 2'
  end

  def test_rejects_invalid_context
    assert_raises(RLM::ConfigurationError) do
      RLM::PromptBuilder.build("InvalidContext", input: {}, context: Object.new)
    end
  end

  def test_rejects_malformed_context_manifest
    context = Object.new
    context.define_singleton_method(:manifest) { { "files" => [], "inputs" => {} } }

    assert_raises(RLM::ConfigurationError) do
      RLM::PromptBuilder.build("MalformedContext", input: {}, context: context)
    end
  end

  def test_rejects_invalid_limits
    assert_raises(RLM::ConfigurationError) do
      RLM::PromptBuilder.build("InvalidLimits", input: {}, limits: Object.new)
    end
  end
end
