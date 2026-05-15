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
      RLM::ResponseProtocol.tags_for(type).each do |tag|
        assert_includes instructions, tag
      end
    end
  end

  def test_response_protocol_can_be_required_directly
    script = 'require "rlm/response_protocol"; puts RLM::ResponseProtocol.output_instructions'
    output = IO.popen([RbConfig.ruby, "-Ilib", "-e", script], &:read)

    assert_includes output, "<rlm-code>"
    assert_includes output, "<rlm-final>"
  end
end
