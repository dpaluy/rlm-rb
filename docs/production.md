# Production Notes

This guide covers intended host-app setup, error handling, production safety, and local development commands.

## Rails Setup

The optional Rails Railtie is available through `require "rlm/rails"`. It wires Rails cache and logger into
`RLM.config` when Rails is loaded, without adding Rails as a core gem dependency. The Rails install generator creates
the initializer, `RlmTrace` model, `rlm_traces` migration, and `RlmPredictJob` ActiveJob example.

```ruby
# config/application.rb or an initializer
require "rlm/rails"
```

Rails apps can generate the initializer:

```sh
bin/rails generate rlm:install
```

The generator creates:

```ruby
# config/initializers/rlm.rb
RLM.configure do |config|
  config.root_lm = RLM::Lm::RubyLLM.new(model: Rails.application.credentials.dig(:rlm, :root_model))
  config.sub_lm = RLM::Lm::RubyLLM.new(model: Rails.application.credentials.dig(:rlm, :sub_model))

  config.sandbox = RLM::Sandbox::Subprocess.new(timeout_seconds: 10)
  config.cache = Rails.cache
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
```

Run the generated migration before using the ActiveRecord trace store:

```sh
bin/rails db:migrate
```

Use `RLM::Rails::ActiveStorage` to convert blobs, attachments, or attachment collections into `RLM::File` context
objects:

```ruby
context = RLM::Context.new(files: RLM::Rails::ActiveStorage.files(invoice.documents))

RLM.predict(InvoiceExtraction, input: { invoice_id: invoice.id }, context: context)
```

Use the generated `RlmPredictJob` for background execution. It runs through ActiveJob, so Rails can route it to the
async adapter, Sidekiq, GoodJob, or another configured queue adapter:

```ruby
RlmPredictJob.perform_later(
  "InvoiceExtraction",
  { invoice_id: invoice.id },
  { context: RLM::Context.new(files: RLM::Rails::ActiveStorage.files(invoice.documents)) }
)
```

API keys belong in `Rails.application.credentials`, not env files. Per RubyLLM's Rails integration, provider keys are
picked up automatically when set there.

## Error Handling

All RLM errors inherit from `RLM::Error`. Rescue the parent to catch every variant, or rescue specific classes to
handle distinct failure modes.

```ruby
begin
  result = RLM.predict(InvoiceExtraction, input: { invoice_pdf: file })
rescue RLM::BudgetExceededError => e
  logger.warn("RLM budget exceeded: #{e.message}")
rescue RLM::ValidationError
  invoice.update!(needs_review: true, review_reasons: ["validation_failed"])
rescue RLM::SandboxError, RLM::ProviderError, RLM::ToolError
  raise
rescue RLM::ParseError, RLM::ConfigurationError
  raise
rescue RLM::Error
  raise
end
```

Soft failures land on `result.status` instead of raising. Inspect `result.success?`, `result.needs_review?`,
`result.failed?`, and `result.validation_errors` to branch.

| Status | Predicate | Meaning |
|--------|-----------|---------|
| `:completed` | `success?` | Output valid, ready to use. |
| `:needs_review` | `needs_review?` | Budget policy requested review, optionally with a valid partial output. |
| `:failed_validation` | `failed?` | Output invalid after validation. |
| `:budget_exceeded` | `failed?` | Hit a hard limit. |
| `:sandbox_error` | `failed?` | Sandbox violation or crash. |
| `:tool_error` | `failed?` | Tool raised or returned invalid output. |
| `:provider_error` | `failed?` | RubyLLM provider failure. |
| `:aborted` | `failed?` | Run cancelled by caller. |

Budget handling honors `limits.on_budget_exceeded`: `:fail`, `:needs_review`, and conservative `:return_partial` when
a valid submitted output already exists.

## Human Review

Use `RLM::Review.route` when a host app needs an explicit review queue before accepting uncertain results.

```ruby
queue = RLM::Review::MemoryQueue.new
item = RLM::Review.route(result, queue: queue, metadata: { source: "invoice_import" })

queue.resolve(item.id, decision: :approved, reviewer: current_user.email) if item
```

The default policy routes `:needs_review` and `:failed_validation` results. Pass `RLM::Review::Policy.new` with custom
statuses or a predicate for app-specific rules. `MemoryQueue` is process-local; durable Rails persistence is still a v2
host-app concern.

## Production Safety

- `RLM::Sandbox::UnsafeInProcess` executes generated code in the host Ruby process. It is dev/test-only and unsafe.
- `RLM::Sandbox::Subprocess` runs generated Ruby in a separate local process, enforces a wall-clock timeout, captures
  stdout/stderr, enforces context limits, mounts context files under relative `sandbox_path` values, records exit
  status, and removes its temp directory during cleanup.
- `RLM::Sandbox::Docker` runs the same worker protocol through `docker run --rm -i --network none`, mounting only the
  prepared temp workdir into `/workspace`.
- `RLM::Sandbox::Remote` sends prepared context/tool/skill manifests and code to a caller-supplied client, so a host app
  can route execution to its own isolated runner without adding transport dependencies to the gem.
- `RLM::Sandbox::Wasm` uses the same manifest/exec protocol for a host-owned WASM runtime, so apps can integrate
  Wasmtime or another runtime without adding a WASM dependency to the core gem.
- Subprocess and Docker helper calls are proxied to the parent runtime over a narrow JSON-line protocol.
- Mounted files are data, not instructions; generated code should treat file contents as untrusted input.

## Development

Ruby commands should load the shell environment first:

```bash
zsh -lc 'source ~/.zshrc && eval "$(mise activate zsh)" && bundle install'
zsh -lc 'source ~/.zshrc && eval "$(mise activate zsh)" && bundle exec rake test'
zsh -lc 'source ~/.zshrc && eval "$(mise activate zsh)" && RUBOCOP_CACHE_ROOT=tmp/rubocop_cache bundle exec rubocop'
zsh -lc 'source ~/.zshrc && eval "$(mise activate zsh)" && RUBOCOP_CACHE_ROOT=tmp/rubocop_cache bundle exec rake'
```

`RUBOCOP_CACHE_ROOT=tmp/rubocop_cache` keeps RuboCop cache writes inside the repository sandbox.
