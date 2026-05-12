# frozen_string_literal: true

require "test_helper"

class RLM::PredictTest < Minitest::Test
  include TestConfig

  def setup
    setup_config
  end

  def teardown
    teardown_config
  end

  def test_requires_signature
    assert_raises(RLM::ConfigurationError) { RLM::Predict.new(nil) }
  end

  def test_initializes_with_defaults_from_config
    predictor = RLM::Predict.new(:my_signature)
    assert_equal :my_signature, predictor.signature
    assert_kind_of RLM::Sandbox::Mock, predictor.sandbox
    assert_kind_of RLM::Limits, predictor.limits
    assert_empty predictor.tools
    assert_empty predictor.skills
    assert_empty predictor.validators
  end

  def test_overrides_take_precedence_over_config
    custom_limits = RLM::Limits.new(max_iterations: 2)
    predictor = RLM::Predict.new(:my_signature, limits: custom_limits, tools: [:fake_tool])
    assert_same custom_limits, predictor.limits
    assert_equal [:fake_tool], predictor.tools
  end

  def test_call_raises_not_implemented_for_skeleton
    predictor = RLM::Predict.new(:my_signature)
    error = assert_raises(NotImplementedError) { predictor.call({}) }
    assert_match(/RLM::Predict#call is not implemented/, error.message)
  end
end
