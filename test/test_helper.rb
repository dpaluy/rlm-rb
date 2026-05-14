# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require "rlm"
require "minitest/autorun"

module TestConfig
  def before_setup
    RLM.reset_configuration!
    super
  end

  def after_teardown
    super
    RLM.reset_configuration!
  end

  def setup_config
    RLM.reset_configuration!
  end

  def teardown_config
    RLM.reset_configuration!
  end
end
