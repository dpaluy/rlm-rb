# frozen_string_literal: true

require "test_helper"
require "logger"

class RLM::ConfigTest < Minitest::Test
  include TestConfig

  def setup
    setup_config
  end

  def teardown
    teardown_config
  end

  def test_defaults
    config = RLM::Config.new
    assert_nil config.root_lm
    assert_nil config.sub_lm
    assert_kind_of RLM::Sandbox::Mock, config.sandbox
    assert_kind_of RLM::Limits, config.default_limits
    assert_nil config.cache
    assert_equal RLM::ResponseProtocol::DEFAULT, config.response_protocol
  end

  def test_logger_falls_back_to_stderr_logger_without_rails
    config = RLM::Config.new
    assert_kind_of Logger, config.logger
  end

  def test_logger_setter_overrides_default
    custom = Object.new
    config = RLM::Config.new
    config.logger = custom
    assert_same custom, config.logger
  end
end
