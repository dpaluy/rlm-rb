# frozen_string_literal: true

require "rlm/rails"

RLM.configure do |config|
  config.root_lm = RLM::Lm::RubyLLM.new(model: Rails.application.credentials.dig(:rlm, :root_model))
  config.sub_lm = RLM::Lm::RubyLLM.new(model: Rails.application.credentials.dig(:rlm, :sub_model))

  config.sandbox = RLM::Sandbox::Subprocess.new(timeout_seconds: 10)
  config.cache ||= Rails.cache
  config.logger = Rails.logger
  config.trace_store = RLM::TraceStore::ActiveRecord.new(record_class: RlmTrace)

  config.default_limits = RLM::Limits.new(
    max_iterations: 8,
    max_llm_calls: 25,
    max_tool_calls: 20,
    max_runtime_seconds: 120,
    max_cost_cents: 100,
    max_recursion_depth: 1
  )
end
