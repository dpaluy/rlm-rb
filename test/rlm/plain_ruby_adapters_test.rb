# frozen_string_literal: true

require "test_helper"
require "dspy"

class RLM::PlainRubyAdaptersTest < Minitest::Test
  FakeCost = Struct.new(:total, keyword_init: true)
  FakeTokens = Struct.new(:input, :output, keyword_init: true)
  FakeResponse = Struct.new(:content, :cost, :tokens, :model_id, keyword_init: true)
  FakeChat = Struct.new(:response, keyword_init: true) do
    def ask(_prompt)
      response
    end
  end

  InvoiceSummary = Class.new(DSPy::Signature) do
    description "Summarize an invoice"

    input do
      const :text, String
    end

    output do
      const :summary, String
    end
  end

  def test_predict_accepts_dspy_signature_adapter_and_ruby_llm_adapter
    signature = RLM::Signature::Dspy.new(InvoiceSummary)
    lm = ruby_llm_adapter

    result = RLM.predict(signature, input: { text: "Invoice paid" }, lm: lm, sandbox: RLM::Sandbox::Mock.new)

    assert result.success?
    assert_equal({ summary: "paid invoice" }, result.output)
    assert_equal 1, result.cost_cents
    assert_root_usage(result)
  end

  private

  def assert_root_usage(result)
    root_event = result.trace.events.find { |event| event[:type] == :root_lm_called }
    assert_equal "fake-rubyllm-model", root_event[:payload][:usage][:model_id]
    assert_equal 9, root_event[:payload][:usage][:input_tokens]
    assert_equal 4, root_event[:payload][:usage][:output_tokens]
  end

  def ruby_llm_adapter
    RLM::Lm::RubyLLM.new(chat_factory: -> { FakeChat.new(response: fake_response) })
  end

  def fake_response
    FakeResponse.new(
      content: '<rlm-final>{"summary":"paid invoice"}</rlm-final>',
      cost: FakeCost.new(total: "0.01"),
      tokens: FakeTokens.new(input: 9, output: 4),
      model_id: "fake-rubyllm-model"
    )
  end
end
