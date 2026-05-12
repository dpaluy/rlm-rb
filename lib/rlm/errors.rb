# frozen_string_literal: true

module RLM
  class Error < StandardError; end

  class ConfigurationError < Error; end
  class BudgetExceededError < Error; end
  class SandboxError < Error; end
  class ValidationError < Error; end
  class ProviderError < Error; end
  class ToolError < Error; end
  class ParseError < Error; end
  class NoProgressError < Error; end
end
