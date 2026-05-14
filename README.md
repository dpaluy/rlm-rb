# RLM.rb

[![Gem Version](https://badge.fury.io/rb/rlm-rb.svg)](https://badge.fury.io/rb/rlm-rb)
[![CI](https://github.com/dpaluy/rlm/actions/workflows/ci.yml/badge.svg)](https://github.com/dpaluy/rlm/actions/workflows/ci.yml)

Recursive Language Models for Ruby and Rails.

RLM.rb is a Ruby runtime for typed, sandbox-oriented, auditable AI jobs over large application context.
It is designed to integrate with [RubyLLM](https://github.com/crmne/ruby_llm) for provider access and [dspy.rb](https://github.com/vicentereig/dspy.rb)
for typed signatures in future milestones. The current v0.2 work focuses on the recursive execution spine: prompt loop,
file and context mounting, recursive sub-LM calls, typed final output, budget controls, trace events, and a minimal
trace persistence hook.

> **Status: Unreleased v0.2 mock runtime spine.** The released gem is v0.1.0 (skeleton). The main branch contains
> a mock runtime loop with `RLM::Lm::Mock`, `RLM::Sandbox::UnsafeInProcess`, budget enforcement and budget policies,
> trace events, recursive `predict`, prompt building, and a best-effort `trace_store` callable hook. Provider adapters,
> dspy.rb adapters, subprocess/container sandboxing, and Rails integration remain future milestones. `UnsafeInProcess`
> is dev/test-only and executes generated code in the host Ruby process.

## Why

1. Large context breaks simple prompting.
2. Manual chunking and summarization are brittle.
3. Hand-rolled agent loops have unclear state, unclear cost, and poor auditability.

RLM.rb replaces those with a bounded Ruby runtime where the model explores context programmatically, calls smaller
typed LLM functions only when needed, and returns validated Ruby objects with a full execution trace.

## Install

Add the gem to your Gemfile:

```ruby
gem "rlm-rb"
```

Or install directly:

```bash
gem install rlm-rb
```

## Configuration

```ruby
RLM.configure do |config|
  # Provider adapters land in the next milestone.
  # config.root_lm = RubyLLM.chat(model: "anthropic/claude-sonnet-4")
  # config.sub_lm  = RubyLLM.chat(model: "openai/gpt-5-mini")

  config.sandbox = RLM::Sandbox::Mock.new

  config.default_limits = RLM::Limits.new(
    max_iterations: 8,
    max_llm_calls: 25,
    max_tool_calls: 20,
    max_runtime_seconds: 120,
    max_cost_cents: 100,
    max_recursion_depth: 1
  )
end
```

## Mock Runtime API (executable with mock LM)

```ruby
class InvoiceExtraction
  def self.name = "InvoiceExtraction"
  def self.description = "Extract normalized invoice fields from a vendor invoice."
  def self.input_fields = { invoice_pdf: :file, vendor_id: :integer }
  def self.output_fields = { vendor_name: :string, invoice_number: :string, total_cents: :integer }
  def self.validate_input(input) = input.key?(:vendor_id) ? [] : ["vendor_id is required"]
  def self.validate_output(output) = output.key?(:vendor_name) ? [] : ["vendor_name is required"]
end

# Mock LM for testing (no provider needed)
lm = RLM::Lm::Mock.new(responses: ['<rlm-final>{"vendor_name":"Acme","invoice_number":"INV-001","total_cents":10000}</rlm-final>'])

result = RLM.predict(
  InvoiceExtraction,
  input: { vendor_id: 123 },
  lm: lm,
  sandbox: RLM::Sandbox::UnsafeInProcess.new,  # dev/test only: executes in host process
  limits: RLM::Limits.new(max_iterations: 8, max_llm_calls: 25)
)

result.output           # { "vendor_name" => "Acme", ... }
result.trace            # full event stream
result.cost_cents       # accumulated cost
result.status           # :completed, :budget_exceeded, :failed_validation, ...
```

## Intended Production API (future milestone)

```ruby
class InvoiceExtraction < DSPy::Signature
  description "Extract normalized invoice fields from a vendor invoice."

  input do
    const :invoice_pdf, RLM::File
    const :vendor_id, Integer
  end

  output do
    const :vendor_name, String
    const :invoice_number, String
    const :total_cents, Integer
    const :confidence, Float
    const :needs_review, T::Boolean
  end
end

result = RLM.predict(
  InvoiceExtraction,
  input: {
    invoice_pdf: RLM::File.from_path("invoice.pdf"),
    vendor_id: 123
  },
  max_iterations: 10,
  max_llm_calls: 30,
  max_cost_cents: 150
)
```

## What's implemented

| Component | Status |
|-----------|--------|
| `RLM.configure` / `RLM.config` | Ready |
| `RLM::Limits` with PRD defaults | Ready |
| `RLM::File` (path / text / io / ActiveStorage blob) | Ready |
| `RLM::Context` with sandbox-safe manifest | Ready |
| `RLM::Trace` with NDJSON / JSON export | Ready |
| `RLM::Result` with full status enum | Ready |
| `RLM::Sandbox::Base` interface + `Mock` backend | Ready |
| `RLM::Sandbox::UnsafeInProcess` | Ready for dev/test only; executes in host process and mutates global streams during serialized capture |
| `RLM::Tool` base class with category DSL | Ready |
| Error hierarchy | Ready |
| `RLM::Predict#call` | Delegates to `RLM::Runtime` |
| `RLM::Runtime` mock loop | Ready (with `RLM::Lm::Mock`) |
| `RLM::PromptBuilder` | Ready (v0.2 contract) |
| `RLM::CodeExtractor` | Ready |
| `RLM::Runtime::Bridge` | Ready for runtime-owned subcalls, tools, submission, file reads, and logging |
| Budget enforcement and policies (`max_llm_calls`, `max_sub_lm_calls`, `max_tool_calls`, `max_iterations`, `max_cost_cents`, `max_runtime_seconds`, `on_budget_exceeded`) | Ready |
| `trace_store` callable hook | Ready (best-effort; receives terminal `RLM::Result`) |
| Recursive `predict` + depth limit | Ready |
| RubyLLM provider adapter | Future milestone |
| dspy.rb signature adapter | Future milestone |
| `RLM::Sandbox::Subprocess` | Future milestone |
| Rails Railtie, generator, migrations, ActiveStorage adapter | Future milestone |

The table above reflects the current unreleased v0.2 implementation status.

## Rails setup (intended, lands in v0.3)

The Rails integration is not yet implemented, but the intended setup is:

```ruby
# config/initializers/rlm.rb
RLM.configure do |config|
  config.root_lm = RubyLLM.chat(model: Rails.application.credentials.dig(:rlm, :root_model))
  config.sub_lm  = RubyLLM.chat(model: Rails.application.credentials.dig(:rlm, :sub_model))

  config.sandbox = RLM::Sandbox::Subprocess.new   # development
  # config.sandbox = RLM::Sandbox::Docker.new     # production (v0.4)

  config.cache  = Rails.cache
  config.logger = Rails.logger

  config.default_limits = RLM::Limits.new(
    max_iterations: 8,
    max_llm_calls: 25,
    max_tool_calls: 20,
    max_runtime_seconds: 120,
    max_cost_cents: 100,
    max_recursion_depth: 1
  )
end
```

API keys belong in `Rails.application.credentials`, not env files. Per RubyLLM's
[Rails integration](https://rubyllm.com/rails/), provider keys are picked up automatically when set there.

## Error handling

All RLM errors inherit from `RLM::Error`. Rescue the parent to catch every variant, or rescue specific classes
to handle distinct failure modes.

```ruby
begin
  result = RLM.predict(InvoiceExtraction, input: { invoice_pdf: file })
rescue RLM::BudgetExceededError => e
  # Hard limits hit: max_iterations, max_llm_calls, max_cost_cents, max_runtime_seconds.
  logger.warn("RLM budget exceeded: #{e.message}")
rescue RLM::ValidationError => e
  # Final output failed signature validation after repair attempts were exhausted.
  invoice.update!(needs_review: true, review_reasons: ["validation_failed"])
rescue RLM::SandboxError => e
  # Generated code violated sandbox policy or the sandbox backend crashed.
  raise
rescue RLM::ProviderError => e
  # RubyLLM provider call failed (transient retries already exhausted).
  raise
rescue RLM::ToolError => e
  # A registered tool raised an exception or was called with invalid input.
  raise
rescue RLM::ParseError => e
  # Root LM response could not be parsed into <rlm-code>/<rlm-final>.
  raise
rescue RLM::ConfigurationError => e
  # Missing signature, missing root LM, invalid sandbox, etc.
  raise
rescue RLM::Error => e
  # Catch-all for any other RLM-originated failure.
  raise
end
```

Soft failures land on `result.status` instead of raising. Inspect `result.success?`, `result.needs_review?`,
`result.failed?`, and `result.validation_errors` to branch. Budget handling honors `limits.on_budget_exceeded`:
`:fail` returns `:budget_exceeded`, `:needs_review` returns `:needs_review`, and `:return_partial` returns
`:needs_review` only when a valid submitted output already exists; otherwise it fails as `:budget_exceeded`.

| Status | Predicate | Meaning |
|--------|-----------|---------|
| `:completed` | `success?` | Output valid, ready to use. |
| `:needs_review` | `needs_review?` | Budget policy requested review, optionally with a valid submitted partial output. |
| `:failed_validation` | `failed?` | Output invalid after validation. |
| `:budget_exceeded` | `failed?` | Hit a hard limit with `:fail`, or `:return_partial` had no valid submitted output. |
| `:sandbox_error` | `failed?` | Sandbox violation or crash. |
| `:tool_error` | `failed?` | Tool raised or returned invalid output. |
| `:provider_error` | `failed?` | RubyLLM provider failure. |
| `:aborted` | `failed?` | Run cancelled by caller. |

## Production safety

- `RLM::Sandbox::UnsafeInProcess` executes generated code in the host Ruby process. It is dev/test-only and unsafe.
- `UnsafeInProcess` captures `$stdout`/`$stderr` by mutating process-global streams; capture is serialized with a mutex,
  but the sandbox remains unsuitable for production and should not be treated as concurrency-safe isolation.
- The subprocess sandbox is a future milestone for local development.
- Production deployments should use a container sandbox or remote isolated runner (future milestone).
- Generated code must not execute inside the host Ruby process in production. The codebase will hold this invariant.
- Mounted files are data, not instructions; generated code should treat file contents as untrusted input.

## Development

```bash
bundle install
bundle exec rake test       # run the test suite
bundle exec rubocop         # lint
bundle exec rake            # test + rubocop
```

## Contributing

Issues and pull requests welcome at https://github.com/dpaluy/rlm.

## API reference

RLM.rb is designed to integrate with these upstream libraries in future milestones. For provider or signature details, go to source:

- [RubyLLM](https://github.com/crmne/ruby_llm), [Rails integration guide](https://rubyllm.com/rails/) for provider/chat/file API.
- [dspy.rb](https://github.com/vicentereig/dspy.rb), [Signatures guide](https://vicentereig.github.io/dspy.rb/core-concepts/signatures/) for typed input/output contracts.
- The [Recursive Language Models](https://github.com/alexzhang13/rlm) reference implementation and the
  [DSPy RLM module](https://dspy.ai/api/modules/RLM/) for the underlying idea.

## License

MIT, see `LICENSE.txt`.
