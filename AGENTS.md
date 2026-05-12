# Repository Guidelines

## Project Structure & Module Organization

This is a Ruby gem for the `RLM` namespace. Public entrypoint code starts in `lib/rlm.rb`, which requires focused components from `lib/rlm/`. Core value objects and runtime interfaces live there, including `config.rb`, `limits.rb`, `context.rb`, `trace.rb`, `result.rb`, `tool.rb`, and sandbox types under `lib/rlm/sandbox/`.

Tests mirror the source tree under `test/rlm/` and use `test/test_helper.rb` for load path setup and shared configuration reset helpers. Product direction and milestone notes live in `docs/prd.md`; user-facing usage and status notes belong in `README.md`; release notes belong in `CHANGELOG.md`.

## Build, Test, and Development Commands

- `bundle install` installs gem development and test dependencies.
- `bundle exec rake test` runs the Minitest suite from `test/**/*_test.rb`.
- `bundle exec rubocop` runs the repository lint rules from `.rubocop.yml`.
- `bundle exec rake` runs the default task: tests plus RuboCop when RuboCop is available.
- `gem build rlm-rb.gemspec` builds a local gem package for release checks.

## Coding Style & Naming Conventions

Target Ruby 3.2 or newer. Use two-space indentation, frozen string literals, double-quoted strings, and a 120-character line limit. Keep files organized by namespace: `RLM::Trace` belongs in `lib/rlm/trace.rb`, and its test belongs in `test/rlm/trace_test.rb`. Prefer small, explicit Ruby objects over framework assumptions; Rails integration is planned but not currently implemented.

## Testing Guidelines

Use Minitest. Name test files with the `_test.rb` suffix and test classes after the unit under test, for example `RLM::ConfigTest`. Reset global configuration around tests that touch `RLM.config` by including `TestConfig` and calling the helper methods in setup and teardown. Add regression tests for behavior changes before refactoring internals.

## Commit & Pull Request Guidelines

The current history is minimal, so keep commits concise, imperative, and intent-focused, for example `Add sandbox execution result tests`. Pull requests should describe the behavior change, link related issues when available, and include the commands run locally. For API-facing changes, update `README.md`, `CHANGELOG.md`, or `docs/prd.md` as appropriate.

## Security & Configuration Tips

Do not commit provider keys, credentials, generated traces with sensitive data, or local packages under `pkg/`. Generated code must stay isolated behind sandbox interfaces; do not execute model-produced code in the host Ruby process.
