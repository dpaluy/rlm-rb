# RLM.rb

[![Gem Version](https://badge.fury.io/rb/rlm-rb.svg)](https://badge.fury.io/rb/rlm-rb)
[![CI](https://github.com/dpaluy/rlm/actions/workflows/ci.yml/badge.svg)](https://github.com/dpaluy/rlm/actions/workflows/ci.yml)

Recursive Language Models for Ruby.

RLM.rb is a Ruby runtime for typed, sandbox-oriented, auditable AI jobs over large application context.
It integrates with [RubyLLM](https://github.com/crmne/ruby_llm) for provider access and
[dspy.rb](https://github.com/vicentereig/dspy.rb) for typed signatures. The current plain Ruby milestone includes the
recursive execution spine: prompt loop, file and context mounting, recursive sub-LM calls, typed final output, budget
controls, trace events, a RubyLLM LM adapter, a dspy signature adapter, and a minimal trace persistence hook.

> **Status: Plain Ruby adapter milestone.** The released gem is v0.2.0. It includes `RLM::Lm::RubyLLM`,
> `RLM::Signature::Dspy`, `RLM::Lm::Mock`, `RLM::Sandbox::Subprocess`, `RLM::Sandbox::UnsafeInProcess`,
> budget enforcement and budget policies, trace events, recursive `predict`, prompt building, and a best-effort
> `trace_store` callable hook, an in-memory trace store, JSONL eval export from traces/results, plus an in-memory eval
> runner, identical recursive subcall caching, optional telemetry spans, and the plain Ruby CSV skill. Rails integration,
> container/remote sandboxing, most skills, and optimizer integration remain future milestones. `UnsafeInProcess` is dev/test-only
> and executes generated code in the host Ruby process.

## Why

1. Large context breaks simple prompting.
2. Manual chunking and summarization are brittle.
3. Hand-rolled agent loops have unclear state, unclear cost, and poor auditability.

RLM.rb replaces those with a bounded Ruby runtime where the model explores context programmatically, calls smaller
typed LLM functions only when needed, and returns validated Ruby objects with a full execution trace.

## Architecture Layers

RLM.rb separates production AI jobs into five layers:

- **Interface**: typed task contracts through `RLM::Signature` and `RLM::Signature::Dspy`.
- **Inference**: provider and model calls through `RLM::Lm::*`, including `RLM::Lm::RubyLLM`.
- **Rendering**: the RLM response protocol that renders tasks into prompts and parses `<rlm-code>` / `<rlm-final>`.
- **Call graph**: recursive runtime execution through `RLM::Runtime`, sandbox helpers, tools, and sub-signatures.
- **Evals**: trace/result export through `RLM::EvalExample` and `RLM::EvalExporter`, plus `RLM::Eval.run`;
  optimization comes later.

## Install

RLM.rb requires Ruby 3.3 or newer. Ruby 3.2 and older are not supported because dspy.rb is mandatory for the plain
Ruby adapter milestone.

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
  config.root_lm = RLM::Lm::RubyLLM.new(model: "gpt-5-mini")
  config.sub_lm = RLM::Lm::RubyLLM.new(model: "gpt-5-mini")

  config.sandbox = RLM::Sandbox::Subprocess.new(timeout_seconds: 10)

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

`RLM::Lm::RubyLLM` creates a fresh `RubyLLM.chat` for each runtime LM call. That keeps RLM prompts standalone and
prevents conversation history from leaking between root and sub-model calls.

## Plain Ruby API

```ruby
require "dspy"
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

RLM.configure do |config|
  config.root_lm = RLM::Lm::RubyLLM.new(model: "gpt-5-mini")
  config.sub_lm = RLM::Lm::RubyLLM.new(model: "gpt-5-mini")
  config.sandbox = RLM::Sandbox::Subprocess.new(timeout_seconds: 10)
end

signature = RLM::Signature::Dspy.new(InvoiceExtraction)

result = RLM.predict(
  signature,
  input: {
    invoice_text: "Vendor: Acme\nInvoice: INV-001\nTotal: $100.00",
    vendor_id: 123
  },
  limits: RLM::Limits.new(max_iterations: 8, max_llm_calls: 25)
)

result.output
# => { vendor_name: "Acme", invoice_number: "INV-001", total_cents: 10000 }

result.trace.events.find { |event| event[:type] == :root_lm_called }[:payload][:usage]
# => { model_id: "...", input_tokens: ..., output_tokens: ..., cost_cents: ..., cost_known: true }
```

Usage metadata is recorded on `:root_lm_called` and `:sub_lm_called` trace events when an adapter exposes it. It is not
duplicated onto `RLM::Result` in this milestone. RubyLLM cost helpers can return `nil` when model pricing is unknown;
RLM records `cost_known: false`, contributes `0` cents for that call, and cannot enforce unknown provider cost.

## Run a Live Plain Ruby Example

The gem ships one opt-in live example at `examples/plain_ruby_invoice_extraction.rb`. By default it exits before
provider credential checks, LM configuration, or `RLM.predict`, even if provider credentials are already present:

```bash
bundle exec ruby examples/plain_ruby_invoice_extraction.rb
```

To run the live path, configure provider credentials and opt in explicitly:

```bash
RLM_RUN_LIVE_EXAMPLE=1 OPENAI_API_KEY="$OPENAI_API_KEY" \
  bundle exec ruby examples/plain_ruby_invoice_extraction.rb
```

The example uses `RLM::Lm::RubyLLM` for root and sub-LM calls, wraps a real `DSPy::Signature` with
`RLM::Signature::Dspy`, calls the public `RLM.predict(...)` API, and prints result status, typed output, trace id, cost,
and usage payloads when RubyLLM exposes them. Set `RLM_EXAMPLE_MODEL` and `RLM_EXAMPLE_SUB_MODEL` to override the
default model.

The live example uses `RLM::Sandbox::Subprocess`, which runs generated Ruby in a separate local Ruby process and
proxies runtime helpers back to the parent runtime. Rails integration, container/remote sandboxing, broader skill packs,
and production execution examples remain future milestones.

## Mock Runtime API

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

## dspy Signature Adapter

`RLM::Signature::Dspy` wraps a `DSPy::Signature` class behind RLM's internal signature protocol:

- `description`
- `input_fields`
- `output_fields`
- `validate_input`
- `validate_output`
- `coerce_output`

The adapter derives fields and simple validation from dspy JSON schema metadata. Output coercion normalizes parsed
JSON/hash output to schema keys before validation.

## Rails

Rails integration is not yet implemented. Rails remains a v2 milestone tracked in `docs/postponed-issues.md`.

## What's Implemented

| Component | Status |
|-----------|--------|
| `RLM.configure` / `RLM.config` | Ready |
| `RLM::Limits` with PRD defaults | Ready |
| `RLM::File` (path / text / io / ActiveStorage blob) | Ready |
| `RLM::Context` with sandbox-safe manifest | Ready with relative subprocess file paths |
| `RLM::Trace` with NDJSON / JSON export | Ready |
| `RLM::Result` with full status enum | Ready |
| `RLM::TraceReplay` | Ready for deterministic terminal result reconstruction from traces |
| `RLM::Sandbox::Base` interface + `Mock` backend | Ready |
| `RLM::Sandbox::Subprocess` | Ready for local process isolation; supports timeout, stdout/stderr capture and caps, context input/file limits, mounted context files, exit status capture, tempdir cleanup, and bridge-proxied helper calls |
| `RLM::Sandbox::UnsafeInProcess` | Ready for dev/test only; executes in host process and mutates global streams during serialized capture |
| `RLM::Tool` base class with category and schema DSL | Ready |
| `RLM::ToolRegistry` | Ready for read-only application tool registration |
| `RLM::Skill` / `RLM::Skills::CSV` | Ready for dependency-free CSV context reads through `csv_rows` |
| Error hierarchy | Ready |
| `RLM::Predict#call` | Delegates to `RLM::Runtime` |
| `RLM::Runtime` mock loop | Ready (with `RLM::Lm::Mock`) |
| `RLM::PromptBuilder` | Ready (v0.2 contract) |
| `RLM::CodeExtractor` | Ready |
| `RLM::ResponseProtocol` | Ready for the default RLM tag rendering protocol |
| `RLM::EvalExample` / `RLM::EvalExporter` | Ready for trace/result JSONL export |
| `RLM::Eval.run` | Ready for in-memory golden dataset evaluation with caller-supplied metrics |
| `RLM::Runtime::Bridge` | Ready for runtime-owned subcalls, tools, submission, file reads, and logging |
| Budget enforcement and policies (`max_llm_calls`, `max_sub_lm_calls`, `max_tool_calls`, `max_iterations`, `max_cost_cents`, `max_runtime_seconds`, `on_budget_exceeded`) | Ready |
| `trace_store` callable hook | Ready (best-effort; receives terminal `RLM::Result`) |
| `RLM::TraceStore` / `RLM::TraceStore::Memory` | Ready for plain Ruby in-memory result storage |
| Identical recursive subcall caching | Ready through `cache:` / `RLM.config.cache` |
| Optional telemetry spans | Ready through `RLM::Telemetry`; OpenTelemetry-compatible when available |
| Recursive `predict` + depth limit | Ready |
| `RLM::Lm::RubyLLM` provider adapter | Ready |
| `RLM::Signature::Dspy` signature adapter | Ready |
| Trace usage metadata for RubyLLM calls | Ready |
| Rails Railtie, generator, migrations, ActiveStorage adapter | Future milestone |

The table above reflects the current unreleased plain Ruby adapter implementation status.

## Trace stores

Any `trace_store` object only needs to respond to `#call(result)`. `RLM::TraceStore` formalizes that contract and
`RLM::TraceStore::Memory` provides a small plain Ruby store for tests, scripts, and local eval collection.

```ruby
store = RLM::TraceStore::Memory.new

result = RLM.predict(
  InvoiceExtraction,
  input: { invoice_text: "Invoice total: $42" },
  trace_store: store
)

store.fetch(result.trace.id) # => result
store.all                   # => [result]
```

Replay a stored trace into a terminal `RLM::Result` without making provider calls:

```ruby
stored_result = store.fetch(result.trace.id)
replayed = RLM::TraceReplay.result(stored_result.trace)

replayed.status # => :completed
replayed.output # => stored_result.output
```

## Tools

Tools are explicit read-only capabilities exposed to generated runtime code through `tool(tool_name, input_hash)`.
Register tool classes or instances directly, or group them in `RLM::ToolRegistry`.

```ruby
class VendorLookup < RLM::Tool
  description "Look up vendor metadata."
  input_schema vendor_id: :integer
  output_schema vendor_id: :integer, name: :string

  def call(vendor_id:)
    { vendor_id: vendor_id, name: "ACME" }
  end
end

tools = RLM::ToolRegistry.new([VendorLookup])
authorizer = ->(tool:, input:, context:) { tool == VendorLookup && context.inputs[:vendor_id] == input[:vendor_id] }

result = RLM.predict(
  InvoiceExtraction,
  input: { vendor_id: 123, invoice_text: "Invoice total: $42" },
  tools: tools,
  tool_authorizer: authorizer
)
```

`RLM::ToolRegistry` only accepts tools whose category is `:read_only`. A `tool_authorizer` callable can deny a
read-only call before execution; return `true` to allow and `false`/`nil` to reject. Write-capable tools remain a future
milestone.

## CSV skill

`RLM::Skills::CSV` exposes `csv_rows(handle, headers: true)` to generated subprocess code. It reads only context files
by handle and returns JSON-serializable row hashes or arrays.

```ruby
invoice_csv = RLM::File.from_text("totals.csv", "name,total\nACME,42\n")

result = RLM.predict(
  InvoiceExtraction,
  input: { invoice_csv: invoice_csv },
  skills: [RLM::Skills::CSV.new]
)
```

## Eval export

Use the `trace_store` hook to collect terminal results, then export them as JSONL eval examples. Each line contains
the original input, observed output, optional expected output, status, result metadata, and the trace payload needed to
inspect LM calls, tool calls, file reads, validation errors, and cost.

```ruby
results = []

result = RLM.predict(
  InvoiceExtraction,
  input: { invoice_text: "Invoice total: $42" },
  trace_store: ->(terminal_result) { results << terminal_result }
)

jsonl = RLM::EvalExporter.to_jsonl(
  result,
  expected_output: { total_cents: 4200 },
  metadata: { split: "train" }
)

File.write("tmp/rlm-evals.jsonl", "#{jsonl}\n")
```

`RLM::EvalExporter.to_jsonl(results)` accepts either `RLM::Result` or `RLM::Trace` records. Result records preserve
the final validated output and runtime counters; trace-only records use the last submitted output when available.

Run a small golden dataset with a caller-supplied metric:

```ruby
metric = ->(expected:, actual:, **) { expected == actual }

report = RLM::Eval.run(
  InvoiceExtraction,
  examples: [
    {
      input: { invoice_text: "Invoice total: $42" },
      expected_output: { total_cents: 4200 }
    }
  ],
  metric: metric
)

report.total    # => 1
report.passed   # => 1
report.score    # => 1.0
```

The eval runner is intentionally local and synchronous. It does not persist datasets, run dspy optimizers, or manage
provider credentials; pass normal `RLM.predict` options or inject `predictor:` for custom execution.

## Subcall caching

Pass a cache object to reuse identical recursive `predict(...)` subcalls within and across runs. The cache key includes
the sub-signature name and a canonicalized input payload. Root LM calls, file reads, and tool calls are not cached.

```ruby
cache = {}

result = RLM.predict(
  InvoiceExtraction,
  input: { invoice_text: "Invoice total: $42" },
  signatures: [VendorNormalization],
  cache: cache
)
```

Plain Ruby hashes are supported. Cache objects that respond to `fetch` and `write` are also supported.

## Telemetry

`RLM::Telemetry` is dependency-free. When given a tracer object that responds to `in_span`, it records `rlm.run` and
`rlm.lm_call` spans. Without a tracer, it is a no-op. If the `opentelemetry-api` gem is present and configured, the
default telemetry object uses `OpenTelemetry.tracer_provider.tracer("rlm-rb")`.

```ruby
RLM.configure do |config|
  config.telemetry = RLM::Telemetry.default
end
```

## Rails setup (intended v2 milestone)

The Rails integration is not yet implemented, but the intended setup is:

```ruby
# config/initializers/rlm.rb
RLM.configure do |config|
  config.root_lm = RLM::Lm::RubyLLM.new(model: Rails.application.credentials.dig(:rlm, :root_model))
  config.sub_lm = RLM::Lm::RubyLLM.new(model: Rails.application.credentials.dig(:rlm, :sub_model))

  config.sandbox = RLM::Sandbox::Subprocess.new(timeout_seconds: 10)
  # config.sandbox = RLM::Sandbox::Docker.new     # future production hardening

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
- `RLM::Sandbox::Subprocess` runs generated Ruby in a separate local process, enforces a wall-clock timeout, captures
  stdout/stderr, enforces context input/file limits, mounts context files under relative manifest `sandbox_path` values,
  records exit status, and removes its temp directory during cleanup.
- Subprocess helper calls (`predict`, `tool`, `submit`, `read_file`, `list_files`, `log`) are proxied to the parent
  runtime over a narrow JSON-line protocol.
- Production deployments should use a container sandbox or remote isolated runner (future milestone).
- Generated code must not execute inside the host Ruby process in production. The codebase will hold this invariant.
- Mounted files are data, not instructions; generated code should treat file contents as untrusted input.

## Development

```bash
zsh -lc 'source ~/.zshrc && eval "$(mise activate zsh)" && bundle install'
zsh -lc 'source ~/.zshrc && eval "$(mise activate zsh)" && bundle exec rake test'
zsh -lc 'source ~/.zshrc && eval "$(mise activate zsh)" && bundle exec rubocop'
zsh -lc 'source ~/.zshrc && eval "$(mise activate zsh)" && bundle exec rake'
```

## Contributing

Issues and pull requests welcome at https://github.com/dpaluy/rlm.

## API reference

RLM.rb integrates with these upstream libraries. For provider or signature details, go to source:

- [RubyLLM](https://github.com/crmne/ruby_llm), [chat guide](https://rubyllm.com/chat/) for provider, chat, token, and cost APIs.
- [dspy.rb](https://github.com/vicentereig/dspy.rb), [Signatures guide](https://oss.vicente.services/dspy.rb/core-concepts/signatures/) for typed input/output contracts.
- The [Recursive Language Models](https://github.com/alexzhang13/rlm) reference implementation and the
  [DSPy RLM module](https://dspy.ai/api/modules/RLM/) for the underlying idea.

## License

MIT, see `LICENSE.txt`.
