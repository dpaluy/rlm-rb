# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- `RLM::Sandbox::Subprocess` local process sandbox with timeout enforcement, stdout/stderr capture and caps, exit
  status capture, tempdir cleanup, and JSON-line proxying for runtime helpers.
- Runtime integration coverage proving `RLM.predict(...)` can execute generated code through the subprocess sandbox.
- `RLM::ResponseProtocol` as the named home for the default `<rlm-code>` / `<rlm-final>` rendering contract.
- `RLM::EvalExample` and `RLM::EvalExporter` for converting terminal results or traces into JSONL eval examples.
- `RLM::Eval.run` for in-memory golden dataset evaluation with caller-supplied metrics.
- `RLM::TraceStore` and `RLM::TraceStore::Memory` for plain Ruby terminal result storage.
- `RLM::ToolRegistry` for registering read-only application tools.
- `RLM::Tool.input_schema` and `RLM::Tool.output_schema` for shallow JSON-shaped tool contract validation.
- `tool_authorizer` hook on config and prediction calls to approve or deny read-only tool execution.
- Identical recursive subcall caching through `cache:` / `RLM.config.cache`.
- `RLM::TraceReplay` for reconstructing terminal `RLM::Result` objects from completed traces.
- `RLM::Telemetry` for optional dependency-free run and LM-call spans with OpenTelemetry-compatible tracers.
- Subprocess sandbox enforcement for `max_input_bytes`, `max_files`, and `max_file_bytes`.
- Context file mounting under subprocess workdir-relative `sandbox_path` values.
- `RLM::Skill` and dependency-free `RLM::Skills::CSV` with subprocess `csv_rows` helper support.
- Dependency-free `RLM::Skills::Directory` with subprocess `directory_files` and `grep_files` helper support.
- Dependency-free `RLM::Skills::PDF` with subprocess `pdf_info` and `pdf_text_preview` helper support.
- Dependency-free `RLM::Skills::HTML` with subprocess `html_text` and `html_links` helper support.
- Runtime cache reuse for identical context file reads, read-only tool calls, and skill calls.
- `RLM::ResponseProtocol::JSON` for models that should return `{"type":"code"|"final","content":...}` instead of
  the default tag-delimited protocol.

### Changed

- The shipped live plain Ruby example now uses `RLM::Sandbox::Subprocess` instead of the dev/test-only
  `UnsafeInProcess` backend.
- README now documents RLM.rb's five architecture layers: interface, inference, rendering, call graph, and evals.
- `RLM::ResponseProtocol::Tags` is now the explicit default response protocol while preserving the existing
  `RLM::ResponseProtocol.output_instructions` and `tags_for` compatibility methods.

## [0.2.0] - 2026-05-15

### Added

- Shipped `examples/plain_ruby_invoice_extraction.rb` as an opt-in live plain Ruby smoke example for real RubyLLM
  and dspy adapters.
- `RLM::Lm::RubyLLM` provider adapter for root and sub-LM calls through RubyLLM.
- `RLM::Signature::Dspy` adapter for wrapping dspy.rb signatures behind the existing RLM signature protocol.
- `RLM::Signature.coerce_output` hook for normalizing parsed final output before validation.
- Optional `usage` payloads on `:root_lm_called` and `:sub_lm_called` trace events for adapters that expose token
  and cost metadata.
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

### Changed

- Ruby compatibility now requires Ruby `>= 3.3.0` because dspy.rb support is part of the plain Ruby milestone.
- Runtime final-output validation now runs after signature-level output coercion.

### Fixed

- Unknown RubyLLM provider costs are recorded as `cost_known: false`, contribute `0` cents for that call, and do not
  crash cost accounting.

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
