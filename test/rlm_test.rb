# frozen_string_literal: true

require "test_helper"

class RLMTest < Minitest::Test
  include TestConfig

  def setup
    setup_config
  end

  def teardown
    teardown_config
  end

  def test_version_present
    refute_nil RLM::VERSION
    assert_match(/\A\d+\.\d+\.\d+\z/, RLM::VERSION)
  end

  def test_config_returns_config_instance
    assert_kind_of RLM::Config, RLM.config
  end

  def test_prompt_builder_is_loaded
    assert defined?(RLM::PromptBuilder)
  end

  def test_configure_yields_config
    RLM.configure do |config|
      config.cache = :test_cache
    end
    assert_equal :test_cache, RLM.config.cache
  end

  def test_reset_configuration_clears_state
    RLM.configure { |c| c.cache = :one }
    RLM.reset_configuration!
    assert_nil RLM.config.cache
  end

  def test_predict_delegates_to_predict_class
    signature = Class.new do
      def self.name = "InlineSignature"
      def self.description = "Inline test"
      def self.input_fields = {}
      def self.output_fields = { ok: :boolean }
      def self.validate_input(_input) = []
      def self.validate_output(output) = output.key?("ok") ? [] : ["ok is required"]
    end

    result = RLM.predict(signature, input: {}, lm: RLM::Lm::Mock.new(responses: ['<rlm-final>{"ok":true}</rlm-final>']))

    assert result.success?
    assert_equal({ "ok" => true }, result.output)
  end
end
