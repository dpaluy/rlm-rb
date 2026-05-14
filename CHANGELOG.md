# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- `RLM::CodeExtractor` for strict `<rlm-code>` / `<rlm-final>` response parsing.
- `RLM::Lm::Mock` for deterministic runtime-spine tests.
- `RLM::PromptBuilder` for deterministic strict prompt construction from signatures, inputs, context
  manifests, and limits.
- `RLM::Runtime::Bridge` for sandbox-exposed `predict`, `tool`, `submit`, `read_file`,
  `list_files`, and `log` runtime services.
- `RLM::Signature` protocol helpers for runtime-independent signature validation.
- `RLM::Sandbox::UnsafeInProcess` for dev/test-only runtime-spine integration tests.
- `RLM::Runtime` mock execution loop with prompt building, LM calls, code/final extraction,
  sandbox execution, recursive subcalls, validation, budget policies, and `RLM::Result` output.
- `RLM::Predict#call` now delegates to the runtime spine.
- Budget enforcement expanded to `max_sub_lm_calls`, `max_tool_calls`, `max_cost_cents`, and `max_runtime_seconds`.
- Budget policies are honored: `:fail`, `:needs_review`, and conservative `:return_partial` when a valid submitted
  output already exists.
- `trace_store` is forwarded into runtime as a best-effort callable hook receiving the terminal `RLM::Result`.
- `RLM::ToolError` is preserved through sandbox execution and reported as `status: :tool_error`.
- Trace event completeness: `:budget_checked` recorded at all budget checks, `:run_failed` recorded on all failure paths.
- PromptBuilder v0.2 contract: signature description, input/output fields, available helpers, safety instructions.
- Parse failures are deterministic and fail-closed (deferred repair attempts to future milestone).
- Sandbox cleanup proven across all failure modes (success, validation, parse, provider, budget, sandbox errors).
- `RLM::Sandbox::UnsafeInProcess` serializes process-global stream capture with a mutex while remaining dev/test-only
  and unsuitable for production isolation.

## [0.1.0] - 2026-05-12

Skeleton release. Establishes the public types, configuration surface, sandbox
interface, and error hierarchy that the runtime milestone will build on.
`RLM::Predict#call` raises `NotImplementedError` until the runtime loop lands in
v0.2.

### Added

- `RLM::VERSION`, `RLM.configure`, `RLM.config`, `RLM.reset_configuration!`.
- Error hierarchy (`RLM::Error`, `ConfigurationError`, `BudgetExceededError`, `SandboxError`,
  `ValidationError`, `ProviderError`, `ToolError`, `ParseError`, `NoProgressError`).
- `RLM::Limits` with PRD defaults and validation.
- `RLM::File` with `from_path`, `from_text`, `from_io`, and `from_active_storage` constructors.
- `RLM::Context` with file handles and sandbox-safe manifest.
- `RLM::Trace` with typed events, NDJSON/JSON export, and basic counters.
- `RLM::Result` with the documented status enum and predicates.
- `RLM::Sandbox::Base` interface plus `Sandbox::ExecutionResult` and `Sandbox::Mock` for tests.
- `RLM::Tool` base class with category DSL.
- `RLM::Predict` skeleton (`#call` raises `NotImplementedError` until the runtime loop lands).

### Not yet implemented (tracked for future milestones)

- RubyLLM root/sub-LM adapters.
- dspy.rb signature adapter and output validation.
- `RLM::Sandbox::Subprocess` backend.
- Rails integration (Railtie, generator, migrations, ActiveStorage adapter).
- PDF/CSV/Directory skills.
