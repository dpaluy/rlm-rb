# frozen_string_literal: true

require "bundler/setup"
require "dspy"
require "json"
require "rlm"

class InvoiceExtraction < DSPy::Signature
  description "Extract normalized invoice fields from a vendor invoice."

  input do
    const :invoice_text, String
    const :vendor_id, Integer
  end

  output do
    const :vendor_name, String
    const :invoice_number, String
    const :total_cents, Integer
  end
end

def live_example_enabled?
  ENV["RLM_RUN_LIVE_EXAMPLE"] == "1"
end

def provider_configured?
  !ENV["OPENAI_API_KEY"].to_s.empty?
end

def print_skipped_message
  puts "Skipped live RLM example."
  puts "Set RLM_RUN_LIVE_EXAMPLE=1 and OPENAI_API_KEY to run a real RubyLLM provider call."
  puts "Optional: set RLM_EXAMPLE_MODEL and RLM_EXAMPLE_SUB_MODEL to override the default model."
end

def usage_events(result)
  result.trace.events.select { |event| %i[root_lm_called sub_lm_called].include?(event[:type]) }
end

unless live_example_enabled?
  print_skipped_message
  exit 0
end

unless provider_configured?
  warn "RLM_RUN_LIVE_EXAMPLE=1 is set, but OPENAI_API_KEY is missing."
  warn "Configure provider credentials before running the live example."
  exit 1
end

root_model = ENV.fetch("RLM_EXAMPLE_MODEL", "gpt-5-mini")
sub_model = ENV.fetch("RLM_EXAMPLE_SUB_MODEL", root_model)

RLM.configure do |config|
  config.root_lm = RLM::Lm::RubyLLM.new(model: root_model)
  config.sub_lm = RLM::Lm::RubyLLM.new(model: sub_model)

  # Dev/test only: UnsafeInProcess runs generated Ruby code in this host process.
  config.sandbox = RLM::Sandbox::UnsafeInProcess.new
end

signature = RLM::Signature::Dspy.new(InvoiceExtraction)

result = RLM.predict(
  signature,
  input: {
    invoice_text: "Vendor: Acme Supplies\nInvoice: INV-001\nTotal: $100.00",
    vendor_id: 123
  },
  limits: RLM::Limits.new(max_iterations: 8, max_llm_calls: 25, max_recursion_depth: 1)
)

puts "status: #{result.status}"
puts "trace_id: #{result.trace.id}"
puts "cost_cents: #{result.cost_cents}"
puts "output:"
puts JSON.pretty_generate(result.output)

usage_events(result).each do |event|
  next unless event[:payload][:usage]

  puts "#{event[:type]} usage:"
  puts JSON.pretty_generate(event[:payload][:usage])
end
