# frozen_string_literal: true

require "test_helper"

class RLM::CodeExtractorTest < Minitest::Test
  def test_extracts_code_block
    source = "<rlm-code>puts \"hello\"\n</rlm-code>"

    result = RLM::CodeExtractor.extract(source)

    assert_equal :code, result.type
    assert_predicate result, :code?
    refute_predicate result, :final?
    assert_equal "puts \"hello\"\n", result.content
    assert_equal({ type: :code, content: "puts \"hello\"\n" }, result.to_h)
  end

  def test_extracts_final_block_as_json
    result = RLM::CodeExtractor.extract('<rlm-final>{"ok":true,"items":[1,2]}</rlm-final>')

    assert_equal :final, result.type
    assert_predicate result, :final?
    refute_predicate result, :code?
    assert_equal({ "ok" => true, "items" => [1, 2] }, result.content)
  end

  def test_extracts_json_protocol_code
    result = RLM::CodeExtractor.extract(
      '{"type":"code","content":"submit({\\"summary\\"=>\\"ok\\"})"}',
      protocol: RLM::ResponseProtocol::JSON
    )

    assert_equal :code, result.type
    assert_equal 'submit({"summary"=>"ok"})', result.content
  end

  def test_extracts_json_protocol_final_output
    result = RLM::CodeExtractor.extract(
      '{"type":"final","content":{"summary":"done"}}',
      protocol: RLM::ResponseProtocol::JSON
    )

    assert_equal :final, result.type
    assert_equal({ "summary" => "done" }, result.content)
  end

  def test_json_protocol_rejects_non_string_code_content
    assert_parse_error('{"type":"code","content":{"ruby":"puts 1"}}', protocol: RLM::ResponseProtocol::JSON)
  end

  def test_extracts_xml_protocol_code
    result = RLM::CodeExtractor.extract(
      '<response type="code"><content><![CDATA[submit({"summary"=>"ok"})]]></content></response>',
      protocol: RLM::ResponseProtocol::XML
    )

    assert_equal :code, result.type
    assert_equal 'submit({"summary"=>"ok"})', result.content
  end

  def test_extracts_xml_protocol_final_output
    result = RLM::CodeExtractor.extract(
      '<response type="final"><content>{"summary":"done"}</content></response>',
      protocol: RLM::ResponseProtocol::XML
    )

    assert_equal :final, result.type
    assert_equal({ "summary" => "done" }, result.content)
  end

  def test_xml_protocol_rejects_invalid_final_json
    assert_parse_error(
      '<response type="final"><content>{not json}</content></response>',
      protocol: RLM::ResponseProtocol::XML
    )
  end

  def test_permits_surrounding_whitespace
    result = RLM::CodeExtractor.extract("\n  <rlm-code>1 + 1</rlm-code>\n\t")

    assert_equal :code, result.type
    assert_equal "1 + 1", result.content
  end

  def test_rejects_non_string_input
    assert_parse_error(nil)
  end

  def test_rejects_response_without_block
    assert_parse_error("puts 1")
  end

  def test_rejects_both_code_and_final_blocks
    assert_parse_error('<rlm-code>puts 1</rlm-code><rlm-final>{"ok":true}</rlm-final>')
  end

  def test_rejects_duplicate_code_blocks
    assert_parse_error("<rlm-code>1</rlm-code>\n<rlm-code>2</rlm-code>")
  end

  def test_rejects_duplicate_final_blocks
    assert_parse_error('<rlm-final>{"a":1}</rlm-final><rlm-final>{"b":2}</rlm-final>')
  end

  def test_rejects_unclosed_opening_tag
    assert_parse_error("<rlm-code>puts 1")
  end

  def test_rejects_unmatched_closing_tag
    assert_parse_error("puts 1</rlm-code>")
  end

  def test_rejects_closing_tag_before_opening_tag
    assert_parse_error("</rlm-code><rlm-code>puts 1")
  end

  def test_rejects_nested_tags
    assert_parse_error("<rlm-code>before <rlm-code>nested</rlm-code> after</rlm-code>")
  end

  def test_rejects_non_whitespace_before_block
    assert_parse_error("Here is the code:\n<rlm-code>puts 1</rlm-code>")
  end

  def test_rejects_non_whitespace_after_block
    assert_parse_error("<rlm-code>puts 1</rlm-code>\nDone")
  end

  def test_rejects_invalid_json_in_final_block
    assert_parse_error("<rlm-final>{not json}</rlm-final>")
  end

  def test_result_rejects_unknown_type
    assert_raises(ArgumentError) do
      RLM::CodeExtractor::Result.new(type: :unknown, content: nil)
    end
  end

  private

  def assert_parse_error(response, protocol: RLM::ResponseProtocol::DEFAULT)
    assert_raises(RLM::ParseError) do
      RLM::CodeExtractor.extract(response, protocol: protocol)
    end
  end
end
