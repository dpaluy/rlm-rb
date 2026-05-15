# Production Notes

This guide covers intended host-app setup, error handling, production safety, and local development commands.

## Rails Setup

Rails integration is not yet implemented. Rails remains a v2 milestone tracked in `docs/postponed-issues.md`.

The intended v2 setup is:

```ruby
# config/initializers/rlm.rb
RLM.configure do |config|
  config.root_lm = RLM::Lm::RubyLLM.new(model: Rails.application.credentials.dig(:rlm, :root_model))
  config.sub_lm = RLM::Lm::RubyLLM.new(model: Rails.application.credentials.dig(:rlm, :sub_model))

  config.sandbox = RLM::Sandbox::Subprocess.new(timeout_seconds: 10)
  config.cache = Rails.cache
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

## Production Safety

- `RLM::Sandbox::UnsafeInProcess` executes generated code in the host Ruby process. It is dev/test-only and unsafe.
- `RLM::Sandbox::Subprocess` runs generated Ruby in a separate local process, enforces a wall-clock timeout, captures
  stdout/stderr, enforces context limits, mounts context files under relative `sandbox_path` values, records exit
  status, and removes its temp directory during cleanup.
- Subprocess helper calls are proxied to the parent runtime over a narrow JSON-line protocol.
- Production deployments should use a container sandbox or remote isolated runner when those backends land.
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
