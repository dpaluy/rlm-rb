# RLM.rb

[![Gem Version](https://badge.fury.io/rb/rlm-rb.svg)](https://badge.fury.io/rb/rlm-rb)
[![CI](https://github.com/dpaluy/rlm/actions/workflows/ci.yml/badge.svg)](https://github.com/dpaluy/rlm/actions/workflows/ci.yml)

Recursive Language Models for Ruby and Rails.

RLM.rb is a Ruby/Rails-native runtime for typed, sandboxed, auditable AI jobs over large application context.
It depends on [RubyLLM](https://github.com/crmne/ruby_llm) for provider access and [dspy.rb](https://github.com/vicentereig/dspy.rb)
for typed signatures, and adds the missing recursive execution runtime: sandbox, REPL loop, file and context mounting,
recursive sub-LM calls, typed final output, budget controls, and durable trajectories.

> **Status: v0.1.0 skeleton.** Core types are in place. The runtime loop, provider adapters, signature adapter,
> subprocess sandbox, and Rails integration are not yet implemented and are tracked in the v0.2 milestone in
> `docs/prd.md`. `RLM::Predict#call` raises `NotImplementedError` in this release.

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

## Intended API (not yet executable)

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

result.output           # typed object
result.trace            # readable steps, llm calls, tool calls
result.cost_cents       # accumulated cost
result.status           # :completed, :needs_review, :budget_exceeded, ...
```

## What's in this skeleton today

| Component | Status |
|-----------|--------|
| `RLM.configure` / `RLM.config` | Ready |
| `RLM::Limits` with PRD defaults | Ready |
| `RLM::File` (path / text / io / ActiveStorage blob) | Ready |
| `RLM::Context` with sandbox-safe manifest | Ready |
| `RLM::Trace` with NDJSON / JSON export | Ready |
| `RLM::Result` with full status enum | Ready |
| `RLM::Sandbox::Base` interface + `Mock` backend | Ready |
| `RLM::Tool` base class with category DSL | Ready |
| Error hierarchy | Ready |
| `RLM::Predict` skeleton | Stub, raises on `#call` |
| RubyLLM provider adapter | Not yet |
| dspy.rb signature adapter | Not yet |
| Runtime execution loop + recursive `predict` | Not yet |
| `RLM::Sandbox::Subprocess` | Not yet |
| Rails Railtie, generator, migrations, ActiveStorage adapter | Not yet |

See `docs/prd.md` for the full product spec and v0.2 milestone list.

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
rescue RLM::NoProgressError => e
  # The model emitted no new progress across iterations.
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
`result.failed?`, and `result.validation_errors` to branch.

| Status | Predicate | Meaning |
|--------|-----------|---------|
| `:completed` | `success?` | Output valid, ready to use. |
| `:needs_review` | `needs_review?` | Output present but validation flagged it or budget policy is `:needs_review`. |
| `:failed_validation` | `failed?` | Output invalid after repair attempts. |
| `:budget_exceeded` | `failed?` | Hit a hard limit and policy is `:fail`. |
| `:sandbox_error` | `failed?` | Sandbox violation or crash. |
| `:tool_error` | `failed?` | Tool raised or returned invalid output. |
| `:provider_error` | `failed?` | RubyLLM provider failure. |
| `:aborted` | `failed?` | Run cancelled by caller. |

## Production safety (when the runtime loop ships)

- The subprocess sandbox planned for v0.2 is intended for local development and low-risk internal use.
- Production deployments should use the Docker sandbox (v0.4) or a remote isolated runner.
- Generated code must not execute inside the host Ruby process. The codebase will hold this invariant.
- Mounted files are data, not instructions. Prompt injection mitigations are documented in the PRD.

## Development

```bash
bundle install
bundle exec rake test       # 58 runs / 139 assertions / 0 failures
bundle exec rubocop         # lint
bundle exec rake            # test + rubocop
```

## Contributing

Issues and pull requests welcome at https://github.com/dpaluy/rlm.

## API reference

RLM.rb sits on top of two upstream libraries. When you need provider or signature details, go to source:

- [RubyLLM](https://github.com/crmne/ruby_llm), [Rails integration guide](https://rubyllm.com/rails/) for provider/chat/file API.
- [dspy.rb](https://github.com/vicentereig/dspy.rb), [Signatures guide](https://vicentereig.github.io/dspy.rb/core-concepts/signatures/) for typed input/output contracts.
- The [Recursive Language Models](https://github.com/alexzhang13/rlm) reference implementation and the
  [DSPy RLM module](https://dspy.ai/api/modules/RLM/) for the underlying idea.

## License

MIT, see `LICENSE.txt`.
