# RLM.rb

[![Gem Version](https://badge.fury.io/rb/rlm-rb.svg)](https://badge.fury.io/rb/rlm-rb)
[![CI](https://github.com/dpaluy/rlm/actions/workflows/ci.yml/badge.svg)](https://github.com/dpaluy/rlm/actions/workflows/ci.yml)

Recursive Language Models for Ruby.

RLM.rb is a plain Ruby runtime for typed, sandbox-oriented, auditable AI jobs over large application context. It
integrates with [RubyLLM](https://github.com/crmne/ruby_llm) for provider calls and
[dspy.rb](https://github.com/vicentereig/dspy.rb) for typed signatures.

> **Status:** the released gem is v0.2.0. The current main branch contains the plain Ruby runtime spine, real RubyLLM
> and dspy adapters, subprocess isolation, context skills, eval export, local evals, optimizer integration, caching,
> and telemetry. Rails integration remains a v2 milestone.

## Why

1. Large context breaks simple prompting.
2. Manual chunking and summarization are brittle.
3. Hand-rolled agent loops have unclear state, unclear cost, and poor auditability.

RLM.rb replaces those with a bounded runtime where the model explores context programmatically, calls smaller typed LLM
functions only when needed, and returns validated Ruby objects with a full execution trace.

## Install

RLM.rb requires Ruby 3.3 or newer. Ruby 3.2 and older are not supported because dspy.rb is mandatory for the plain Ruby
adapter milestone.

```ruby
gem "rlm-rb"
```

## Quick Start

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

result = RLM.predict(
  RLM::Signature::Dspy.new(InvoiceExtraction),
  input: {
    invoice_text: "Vendor: Acme\nInvoice: INV-001\nTotal: $100.00",
    vendor_id: 123
  },
  limits: RLM::Limits.new(max_iterations: 8, max_llm_calls: 25)
)

result.output
# => { vendor_name: "Acme", invoice_number: "INV-001", total_cents: 10000 }
```

For a deterministic no-provider test path, use `RLM::Lm::Mock` and `RLM::Sandbox::UnsafeInProcess`. The unsafe sandbox
executes generated code in the host process and is only for dev/test.

## Architecture Layers

- **Interface:** typed task contracts through `RLM::Signature` and `RLM::Signature::Dspy`.
- **Inference:** provider and model calls through `RLM::Lm::*`, including `RLM::Lm::RubyLLM`.
- **Rendering:** response protocols through `RLM::ResponseProtocol::Tags` and `RLM::ResponseProtocol::JSON`.
- **Call graph:** recursive runtime execution through `RLM::Runtime`, sandbox helpers, tools, and sub-signatures.
- **Evals:** trace/result export, local evals, and dspy optimizer entrypoints.

## Current Surface

| Component | Status |
|-----------|--------|
| `RLM.configure` / `RLM.config` | Ready |
| `RLM::Limits` | Ready |
| `RLM::File` and `RLM::Context` | Ready with subprocess-safe manifests and mounted file paths |
| `RLM::Trace`, `RLM::Result`, `RLM::TraceReplay` | Ready |
| `RLM::Sandbox::Subprocess` / `RLM::Sandbox::Docker` | Ready for local process and container isolation |
| `RLM::Sandbox::UnsafeInProcess` | Dev/test only |
| `RLM::Tool`, `RLM::ToolRegistry`, tool schemas, tool authorization | Ready for read-only tools |
| `RLM::Skill` plus CSV, directory, PDF, HTML, and browser skills | Ready for dependency-free context inspection |
| `RLM::Predict`, `RLM::Runtime`, `RLM::Runtime::Bridge` | Ready |
| `RLM::PromptBuilder`, `RLM::CodeExtractor`, `RLM::ResponseProtocol` | Ready |
| `RLM::EvalExample`, `RLM::EvalExporter`, `RLM::Eval.run` | Ready |
| `RLM::Optimizer::Dspy` | Ready for caller-supplied dspy teleprompters |
| `RLM::TraceStore` / `RLM::TraceStore::Memory` / `RLM::TraceStore::ActiveRecord` | Ready for plain Ruby and Rails storage |
| `RLM::Review` / `RLM::Review::MemoryQueue` | Ready for plain Ruby review routing |
| `RLM::Dashboard.summary` | Ready for host-app dashboard metrics |
| Runtime caching | Ready for subcalls, file reads, tools, and skills |
| Optional telemetry spans, ActiveSupport notifications, and dspy spans | Ready through `RLM::Telemetry` |
| `RLM::Lm::RubyLLM` and `RLM::Signature::Dspy` | Ready |
| Optional Rails Railtie | Ready through `require "rlm/rails"` when Rails is loaded |
| Rails install generator | Ready for initializer, trace model, and trace migration setup |
| ActiveStorage adapter | Ready through `RLM::Rails::ActiveStorage` |
| ActiveJob / Sidekiq / GoodJob examples | Ready through generated `RlmPredictJob` |

## Guides

- [Plain Ruby usage](docs/plain-ruby-usage.md): configuration, live example, mock runtime, dspy signatures, and response
  protocols.
- [Runtime features](docs/runtime-features.md): trace stores, tools, skills, evals, dspy optimization, caching, and
  telemetry.
- [Production notes](docs/production.md): intended Rails setup, error handling, production safety, and development
  commands.
- [Product requirements](docs/prd.md): long-form product direction and milestone notes.

## Live Example

The gem ships one opt-in live example:

```bash
bundle exec ruby examples/plain_ruby_invoice_extraction.rb
```

By default it exits before provider credential checks. To run the live path:

```bash
RLM_RUN_LIVE_EXAMPLE=1 OPENAI_API_KEY="$OPENAI_API_KEY" \
  bundle exec ruby examples/plain_ruby_invoice_extraction.rb
```

Set `RLM_EXAMPLE_MODEL` and `RLM_EXAMPLE_SUB_MODEL` to override the default models.

## API Reference

RLM.rb integrates with these upstream libraries:

- [RubyLLM](https://github.com/crmne/ruby_llm), [chat guide](https://rubyllm.com/chat/) for provider, chat, token, and
  cost APIs.
- [dspy.rb](https://github.com/vicentereig/dspy.rb), [Signatures guide](https://oss.vicente.services/dspy.rb/core-concepts/signatures/)
  for typed input/output contracts.
- The [Recursive Language Models](https://github.com/alexzhang13/rlm) reference implementation and
  [DSPy RLM module](https://dspy.ai/api/modules/RLM/) for the underlying idea.

## License

MIT, see `LICENSE.txt`.
