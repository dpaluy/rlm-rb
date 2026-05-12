# frozen_string_literal: true

require "test_helper"

class RLM::Lm::MockTest < Minitest::Test
  def test_returns_scripted_responses_in_order
    lm = RLM::Lm::Mock.new(responses: %w[first second])

    assert_equal "first", lm.call(prompt: "prompt 1")
    assert_equal "second", lm.call(prompt: "prompt 2")
  end

  def test_tracks_call_count_and_prompts
    lm = RLM::Lm::Mock.new(responses: ["response"], cost_cents: 3)

    lm.call(prompt: "hello")

    assert_equal 1, lm.call_count
    assert_equal ["hello"], lm.prompts
    assert_equal "hello", lm.last_prompt
    assert_equal 3, lm.cost_cents
  end

  def test_accepts_additional_call_metadata
    lm = RLM::Lm::Mock.new(responses: ["response"])

    assert_equal "response", lm.call(prompt: "hello", signature: "MySignature")
    assert_equal 1, lm.call_count
  end

  def test_raises_provider_error_when_responses_are_exhausted
    lm = RLM::Lm::Mock.new(responses: ["only"])

    lm.call(prompt: "first")

    error = assert_raises(RLM::ProviderError) do
      lm.call(prompt: "second")
    end
    assert_match(/exhausted/i, error.message)
  end

  def test_requires_responses
    assert_raises(ArgumentError) do
      RLM::Lm::Mock.new(responses: [])
    end
  end

  def test_requires_string_prompts
    lm = RLM::Lm::Mock.new(responses: ["response"])

    assert_raises(RLM::ProviderError) do
      lm.call(prompt: nil)
    end
  end
end
