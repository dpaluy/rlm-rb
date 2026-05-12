# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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

### Not yet implemented (tracked for v0.2+)

- Runtime execution loop, code extractor, runtime bridge, recursive `predict(...)`.
- RubyLLM root/sub-LM adapters.
- dspy.rb signature adapter and output validation.
- `RLM::Sandbox::Subprocess` backend.
- Rails integration (Railtie, generator, migrations, ActiveStorage adapter).
- PDF/CSV/Directory skills.
