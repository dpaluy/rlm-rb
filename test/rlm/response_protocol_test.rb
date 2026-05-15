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

  def test_response_protocol_can_be_required_directly
    script = 'require "rlm/response_protocol"; puts RLM::ResponseProtocol.output_instructions'
    output = IO.popen([RbConfig.ruby, "-Ilib", "-e", script], &:read)

    assert_includes output, "<rlm-code>"
    assert_includes output, "<rlm-final>"
  end
end
