# Postponed Issues

Last updated: 2026-05-15

This document tracks work intentionally deferred beyond the first usable plain-Ruby `rlm-rb` milestone.
The first milestone is limited to real RubyLLM and dspy.rb adapters on top of the existing v0.2 mock runtime spine.

## Completed Baseline Milestone

**Plain Ruby adapter milestone**

Goal:

> A plain Ruby user can run `RLM.predict(...)` through the existing recursive runtime using real RubyLLM-backed model calls and dspy.rb-backed signatures.

Completed scope:

- `RLM::Lm::RubyLLM` root-LM adapter.
- `RLM::Lm::RubyLLM` sub-LM adapter.
- `RLM::Signature::Dspy` signature adapter.
- JSON/hash output coercion into the dspy-backed output contract.
- Provider error normalization into `RLM::ProviderError`.
- Usage/cost metadata capture where RubyLLM exposes it.
- Tests and docs for plain Ruby usage.
- Preserved the current public `RLM.predict(...)` API shape.

## Deferred Issues

| Issue | Deferred Until | Reason |
| --- | --- | --- |
| Rails Railtie | v2 / Rails milestone | First usable milestone is plain Ruby only. |
| Rails install generator | v2 / Rails milestone | Depends on Rails integration and persistence decisions. |
| ActiveRecord trace tables | v2 / Rails milestone | Durable Rails persistence is not required for the first plain-Ruby adapter milestone. |
| ActiveStorage integration beyond duck-typed `RLM::File.from_active_storage` | v2 / Rails milestone | Rails file mounting belongs with the Rails integration pass. |
| ActiveJob / Sidekiq / GoodJob examples | v2 / Rails milestone | Background-job-native execution is a later Rails delivery concern. |
| Subprocess sandbox | Post-adapter sandbox milestone | Adapters should land on the existing runtime spine before introducing process isolation. |
| Docker sandbox | Production-runtime milestone | Docker is a production hardening backend after subprocess semantics are proven. |
| Remote/WASM sandbox | Production-runtime milestone | Later isolation backend, not needed to prove plain Ruby adapter usability. |
| File mounting into subprocess working directories | Sandbox milestone | Requires a real subprocess/container sandbox. |
| Enforcement of `max_input_bytes`, `max_files`, and `max_file_bytes` at sandbox boundary | Sandbox milestone | Meaningful enforcement depends on context mounting and sandbox prep. |
| PDF skill | Skills milestone | Skills should wait until adapter and sandbox contracts are stable. |
| CSV skill | Skills milestone | Same as PDF skill. |
| Directory/codebase skill | Skills milestone | Requires stable file/context inspection semantics. |
| HTML/browser skill | Skills or separate browser milestone | Browser automation is a stated non-goal for the core adapter milestone. |
| Read-only application tool registry | Tools milestone | First adapter milestone only needs LLM/signature integration. |
| Typed tool input/output schemas | Tools milestone | Depends on final tool registry design. |
| Tool authorization hooks | Tools/security milestone | Authorization belongs with real application tool execution. |
| Write-capable tools | Later production milestone or explicit request | Side effects are out of scope for bounded plain-Ruby adapter work. |
| Durable trace store interface | Trace-store milestone | Existing best-effort callable `trace_store` hook is enough for the adapter milestone. |
| Memory trace store | Trace-store milestone | Follows the durable trace-store interface. |
| Trace replay | v1 production-readiness milestone | Requires stable trace schema and persisted traces. |
| Caching identical subcalls | Caching milestone | Adapter behavior should be correct before cache key semantics are frozen. |
| Cache file extraction/tool calls | Caching + skills/tools milestones | Depends on file extraction and tool contracts. |
| OpenTelemetry spans | Observability milestone | Plain Ruby adapter milestone can expose trace/cost data without telemetry dependencies. |
| ActiveSupport notifications | Rails/observability milestone | Rails-specific observability should not enter the core plain-Ruby slice. |
| Langfuse/dspy observability integration | Observability milestone | Defer until dspy adapter behavior is stable. |
| Eval harness | Evals milestone | Useful after real adapters work and examples exist. |
| dspy optimizer integration | Evals/optimization milestone | Requires stable dspy adapter and trace outputs. |
| Human review workflow | Rails/product workflow milestone | Review routing needs persistence and application integration. |
| Dashboards | Product/UI milestone | Depends on durable traces and Rails or another host app surface. |
| Breaking changes to `RLM.predict(...)` public API | Avoid unless explicitly approved | Adapter implementation should preserve the existing call shape. |
| New Rails dependencies in the core gem | Avoid until Rails milestone | Core gem should remain plain-Ruby usable. |

## Maintenance Rule

When implementation work intentionally defers a feature, add it here with:

- the issue name,
- the milestone or condition that should reopen it,
- and the reason it is not part of the current active milestone.

When a postponed issue is completed, move it to `Completed Deferred Issues` with the date and verification evidence.

## Completed Deferred Issues

| Issue | Completed | Verification |
| --- | --- | --- |
| Plain Ruby RubyLLM + dspy adapter milestone | 2026-05-15 | `zsh -lc 'source ~/.zshrc && eval "$(mise activate zsh)" && bundle exec rake test'` passed with 194 runs and 472 assertions. |
