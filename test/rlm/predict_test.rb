# frozen_string_literal: true

require "test_helper"

class RLM::PredictTest < Minitest::Test
  include TestConfig

  FakeSignature = Class.new do
    def self.name = "FakeSignature"
    def self.description = "Fake predict test"
    def self.input_fields = {}
    def self.output_fields = { ok: :boolean }
    def self.validate_input(_input) = []
    def self.validate_output(output) = output.key?("ok") || output.key?(:ok) ? [] : ["ok is required"]
  end

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

  def test_call_runs_runtime
    lm = RLM::Lm::Mock.new(responses: ['<rlm-final>{"ok":true}</rlm-final>'])
    predictor = RLM::Predict.new(FakeSignature, lm: lm)

    result = predictor.call({})

    assert result.success?
    assert_equal({ "ok" => true }, result.output)
  end

  def test_explicit_trace_store_reaches_runtime
    stored = []
    lm = RLM::Lm::Mock.new(responses: ['<rlm-final>{"ok":true}</rlm-final>'])
    predictor = RLM::Predict.new(FakeSignature, lm: lm, trace_store: ->(result) { stored << result })

    result = predictor.call({})

    assert_equal [result], stored
  end

  def test_configured_trace_store_reaches_runtime
    stored = []
    RLM.config.trace_store = ->(result) { stored << result }
    RLM.config.root_lm = RLM::Lm::Mock.new(responses: ['<rlm-final>{"ok":true}</rlm-final>'])

    result = RLM::Predict.new(FakeSignature).call({})

    assert_equal [result], stored
  end
end
