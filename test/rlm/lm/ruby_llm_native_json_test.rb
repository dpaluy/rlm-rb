# frozen_string_literal: true

require "test_helper"

class RLM::Lm::RubyLLMNativeJSONTest < Minitest::Test
  FakeResponse = Struct.new(:content, keyword_init: true)

  class FakeChat
    attr_reader :schema, :prompt

    def with_schema(schema)
      @schema = schema
      self
    end

    def ask(prompt)
      @prompt = prompt
      FakeResponse.new(content: { "summary" => "ok" })
    end
  end

  class NativeSignature
    def self.name = "NativeSignature"

    def self.output_fields
      { summary: :string }
    end
  end

  def test_passes_native_json_schema_to_ruby_llm_chat
    chat = FakeChat.new
    adapter = RLM::Lm::RubyLLM.new(chat_factory: -> { chat })

    content = adapter.call(
      prompt: "summarize",
      signature: "NativeSignature",
      signature_adapter: NativeSignature,
      depth: 0,
      response_protocol: RLM::ResponseProtocol::NativeJSON
    )

    assert_equal({ "summary" => "ok" }, content)
    assert_equal "summarize", chat.prompt
    assert_equal "string", chat.schema.dig(:schema, :properties, "summary", :type)
  end
end
