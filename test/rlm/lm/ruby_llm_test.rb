# frozen_string_literal: true

require "test_helper"

class RLM::Lm::RubyLLMTest < Minitest::Test
  FakeCost = Struct.new(:total, keyword_init: true)
  FakeTokens = Struct.new(
    :input,
    :output,
    :cache_read,
    :cache_write,
    :thinking,
    keyword_init: true
  )
  FakeResponse = Struct.new(:content, :cost, :tokens, :model_id, keyword_init: true)

  class FakeChat
    attr_reader :prompts

    def initialize(response:)
      @response = response
      @prompts = []
    end

    def ask(prompt)
      prompts << prompt
      @response
    end
  end

  def test_success_returns_response_content
    adapter = ruby_llm_adapter(response: fake_response(content: "<rlm-final>{}</rlm-final>"))

    assert_equal "<rlm-final>{}</rlm-final>", adapter.call(prompt: "hello", signature: "Sig", depth: 0)
  end

  def test_success_content_can_be_parsed_by_code_extractor
    adapter = ruby_llm_adapter(response: fake_response(content: '<rlm-final>{"summary":"ok"}</rlm-final>'))

    parsed = RLM::CodeExtractor.extract(adapter.call(prompt: "hello", signature: "Sig", depth: 0))

    assert parsed.final?
    assert_equal({ "summary" => "ok" }, parsed.content)
  end

  def test_provider_exception_is_wrapped_as_provider_error
    adapter = RLM::Lm::RubyLLM.new(chat_factory: -> { raise "sdk boom" })

    error = assert_raises(RLM::ProviderError) do
      adapter.call(prompt: "hello", signature: "Sig", depth: 0)
    end

    assert_match(/sdk boom/, error.message)
  end

  def test_cost_cents_accumulates_decimal_safe_dollar_costs
    responses = [
      fake_response(cost_total: 0.10),
      fake_response(cost_total: 0.20)
    ]
    adapter = ruby_llm_adapter(responses: responses)

    adapter.call(prompt: "first", signature: "Sig", depth: 0)
    adapter.call(prompt: "second", signature: "Sig", depth: 0)

    assert_equal 30, adapter.cost_cents
  end

  def test_nil_cost_contributes_zero_and_marks_usage_cost_unknown
    adapter = ruby_llm_adapter(response: fake_response(cost_total: nil))

    adapter.call(prompt: "hello", signature: "Sig", depth: 0)

    assert_equal 0, adapter.cost_cents
    assert_equal false, adapter.last_usage.fetch(:cost_known)
    assert_equal 0, adapter.last_usage.fetch(:cost_cents)
  end

  def test_last_usage_normalizes_model_tokens_and_cost_fields
    adapter = ruby_llm_adapter(
      response: fake_response(
        cost_total: 0.01,
        tokens: FakeTokens.new(
          input: 10,
          output: 20,
          cache_read: 3,
          cache_write: 4,
          thinking: 5
        ),
        model_id: "fake-model"
      )
    )

    adapter.call(prompt: "hello", signature: "Sig", depth: 0)

    assert_equal expected_usage_payload, adapter.last_usage
  end

  def test_repeated_calls_use_fresh_chat_instances_without_prompt_history
    chats = []
    adapter = RLM::Lm::RubyLLM.new(
      chat_factory: lambda {
        FakeChat.new(response: fake_response).tap { |chat| chats << chat }
      }
    )

    adapter.call(prompt: "first prompt", signature: "Sig", depth: 0)
    adapter.call(prompt: "second prompt", signature: "Sig", depth: 0)

    assert_equal 2, chats.length
    assert_equal ["first prompt"], chats.fetch(0).prompts
    assert_equal ["second prompt"], chats.fetch(1).prompts
  end

  private

  def ruby_llm_adapter(response: nil, responses: nil)
    scripted = responses ? responses.dup : [response || fake_response]
    RLM::Lm::RubyLLM.new(chat_factory: -> { FakeChat.new(response: scripted.shift) })
  end

  def fake_response(content: '<rlm-final>{"summary":"ok"}</rlm-final>', cost_total: 0, tokens: nil, model_id: nil)
    FakeResponse.new(content: content, cost: FakeCost.new(total: cost_total), tokens: tokens, model_id: model_id)
  end

  def expected_usage_payload
    {
      model_id: "fake-model",
      input_tokens: 10,
      output_tokens: 20,
      cache_read_tokens: 3,
      cache_write_tokens: 4,
      thinking_tokens: 5,
      cost_cents: 1,
      cost_known: true
    }
  end
end
