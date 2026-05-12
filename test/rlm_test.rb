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
    error = assert_raises(NotImplementedError) do
      RLM.predict(:my_signature, input: { text: "hi" })
    end
    assert_match(/Predict#call is not implemented/, error.message)
  end
end
