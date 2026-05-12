# frozen_string_literal: true

require "test_helper"

class RLM::ErrorsTest < Minitest::Test
  ERROR_CLASSES = %i[
    ConfigurationError
    BudgetExceededError
    SandboxError
    ValidationError
    ProviderError
    ToolError
    ParseError
    NoProgressError
  ].freeze

  def test_all_error_classes_inherit_from_rlm_error
    ERROR_CLASSES.each do |name|
      klass = RLM.const_get(name)
      assert klass < RLM::Error, "#{name} must inherit from RLM::Error"
    end
  end

  def test_rlm_error_is_standard_error
    assert RLM::Error < StandardError
  end
end
