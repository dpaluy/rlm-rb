# frozen_string_literal: true

require "test_helper"

class RLM::ResponseProtocolTest < Minitest::Test
  def test_tags_for_known_response_types
    assert_equal ["<rlm-code>", "</rlm-code>"], RLM::ResponseProtocol.tags_for(:code)
    assert_equal ["<rlm-final>", "</rlm-final>"], RLM::ResponseProtocol.tags_for(:final)
  end

  def test_rejects_unknown_response_type
    assert_raises(RLM::ParseError) do
      RLM::ResponseProtocol.tags_for(:unknown)
    end
  end

  def test_output_instructions_and_extractor_share_protocol_tags
    instructions = RLM::ResponseProtocol.output_instructions

    RLM::ResponseProtocol::TYPES.each do |type|
      RLM::ResponseProtocol::Tags.tags_for(type).each do |tag|
        assert_includes instructions, tag
      end
    end
  end

  def test_default_protocol_preserves_tag_protocol
    assert_equal RLM::ResponseProtocol::Tags, RLM::ResponseProtocol::DEFAULT
    assert_equal RLM::ResponseProtocol::Tags.output_instructions, RLM::ResponseProtocol.output_instructions
  end

  def test_json_protocol_instructions_describe_json_envelope
    instructions = RLM::ResponseProtocol::JSON.output_instructions

    assert_includes instructions, '{"type":"code"'
    assert_includes instructions, '{"type":"final"'
    assert_includes instructions, "Return exactly one JSON object"
  end

  def test_xml_protocol_instructions_describe_xml_envelope
    instructions = RLM::ResponseProtocol::XML.output_instructions

    assert_includes instructions, '<response type="code">'
    assert_includes instructions, '<response type="final">'
    assert_includes instructions, "Return exactly one XML document"
  end

  def test_native_json_extracts_hash_final_output
    parsed = RLM::ResponseProtocol::NativeJSON.extract({ "summary" => "ok" })

    assert_equal({ type: :final, content: { "summary" => "ok" } }, parsed)
  end

  def test_native_json_builds_output_schema_from_signature
    signature = Struct.new(:output_fields, keyword_init: true).new(output_fields: { total: :integer })

    schema = RLM::ResponseProtocol::NativeJSON.native_schema(signature)

    assert_equal "integer", schema.dig(:schema, :properties, "total", :type)
    assert_equal ["total"], schema.dig(:schema, :required)
  end

  def test_response_protocol_can_be_required_directly
    script = 'require "rlm/response_protocol"; puts RLM::ResponseProtocol.output_instructions'
    output = IO.popen([RbConfig.ruby, "-Ilib", "-e", script], &:read)

    assert_includes output, "<rlm-code>"
    assert_includes output, "<rlm-final>"
  end

  def test_optimizes_response_protocol_with_eval_scores
    seen = []
    predictor = lambda do |_signature, input:, response_protocol:, **_options|
      seen << [input, response_protocol]
      output = response_protocol == RLM::ResponseProtocol::JSON ? { "answer" => "ok" } : { "answer" => "no" }
      RLM::Result.new(trace: RLM::Trace.new, status: :completed, output: output)
    end

    selection = RLM::ResponseProtocol.optimize(
      Object,
      examples: [{ input: { "question" => "x" }, expected_output: { "answer" => "ok" } }],
      metric: ->(expected:, actual:, **) { expected == actual },
      protocols: [RLM::ResponseProtocol::Tags, RLM::ResponseProtocol::JSON],
      predictor: predictor,
      lm: :mock
    )

    assert_equal RLM::ResponseProtocol::JSON, selection.best_protocol
    assert_equal({ "Tags" => 0.0, "JSON" => 1.0 }, selection.scores)
    assert_equal [
      [{ "question" => "x" }, RLM::ResponseProtocol::Tags],
      [{ "question" => "x" }, RLM::ResponseProtocol::JSON]
    ], seen
  end

  def test_response_protocol_selection_requires_protocols
    assert_raises(ArgumentError) do
      RLM::ResponseProtocol.optimize(
        Object,
        examples: [],
        metric: ->(**) { true },
        protocols: []
      )
    end
  end
end
