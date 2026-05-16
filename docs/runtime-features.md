# Runtime Features

This guide covers traces, tools, skills, evals, optimization, caching, response protocols, and telemetry.

## Trace Stores

Any `trace_store` object only needs to respond to `#call(result)`. `RLM::TraceStore` formalizes that contract and
`RLM::TraceStore::Memory` provides a small in-memory store for tests, scripts, and local eval collection. Rails apps
can use `RLM::TraceStore::ActiveRecord` with the generated `RlmTrace` model for durable trace storage.

```ruby
store = RLM::TraceStore::Memory.new

result = RLM.predict(
  InvoiceExtraction,
  input: { invoice_text: "Invoice total: $42" },
  trace_store: store
)

store.fetch(result.trace.id)
store.all
```

```ruby
RLM.configure do |config|
  config.trace_store = RLM::TraceStore::ActiveRecord.new(record_class: RlmTrace)
end
```

Replay a stored trace into a terminal `RLM::Result` without making provider calls:

```ruby
replayed = RLM::TraceReplay.result(result.trace)
```

Build host-app dashboard metrics from in-memory results or persisted records:

```ruby
summary = RLM::Dashboard.summary(store.all)
summary[:status_counts]
summary[:average_duration_ms]
```

## Tools

Tools are explicit read-only capabilities exposed to generated runtime code through `tool(tool_name, input_hash)`.

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

RLM.predict(InvoiceExtraction, input: input, tools: tools, tool_authorizer: authorizer)
```

`RLM::ToolRegistry` accepts all tool categories. Read-only calls may be denied by `tool_authorizer`; write tools marked
`:write_requires_approval` require `tool_authorizer` approval before execution, and disabled dangerous tools never run.

## Skills

Skills expose dependency-free context inspection helpers to generated subprocess code.

```ruby
RLM.predict(
  InvoiceExtraction,
  input: { invoice_csv: RLM::File.from_text("totals.csv", "name,total\nACME,42\n") },
  skills: [RLM::Skills::CSV.new]
)
```

Available helpers:

| Skill | Helpers |
|-------|---------|
| `RLM::Skills::CSV` | `csv_rows(handle, headers: true)` |
| `RLM::Skills::Directory` | `directory_files`, `grep_files(query)` |
| `RLM::Skills::PDF` | `pdf_info(handle)`, `pdf_text_preview(handle, bytes: 4096)`, `pdf_extract_text(handle)`, `pdf_ocr_text(handle)` |
| `RLM::Skills::HTML` | `html_text(handle)`, `html_links(handle)` |
| `RLM::Skills::Browser` | `browser_text(url)`, `browser_links(url)`, `browser_snapshot(url)` |

By default, the PDF skill is metadata/text-preview only. Pass caller-supplied `extractor:` and `ocr:` clients to use
real PDF parsing or OCR libraries in the host app without adding those dependencies to the core gem. The HTML skill is
static extraction only and does not run a browser, JavaScript, or network requests. `RLM::Skills::Browser` accepts a
caller-supplied client for rendered page inspection without adding Playwright, Selenium, or another browser automation
dependency to the core gem.

```ruby
pdf = RLM::Skills::PDF.new(extractor: your_pdf_reader, ocr: your_ocr_service)

RLM.predict(InvoiceExtraction, input: { scan: file }, skills: [pdf])
```

```ruby
browser = RLM::Skills::Browser.new(client: your_browser_client)

RLM.predict(PageSummary, input: { url: "https://example.com" }, skills: [browser])
```

Rails apps that load `require "rlm/rails"` can turn ActiveStorage blobs, attachments, or collections into context files
with `RLM::Rails::ActiveStorage.file(...)` and `RLM::Rails::ActiveStorage.files(...)`.

## Eval Export And Local Evals

Use `trace_store` to collect terminal results, then export them as JSONL eval examples.

```ruby
jsonl = RLM::EvalExporter.to_jsonl(
  result,
  expected_output: { total_cents: 4200 },
  metadata: { split: "train" }
)
```

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
```

`RLM::EvalExporter.to_jsonl(results)` accepts either `RLM::Result` or `RLM::Trace` records. Result records preserve
final validated output and runtime counters; trace-only records use the last submitted output when available.

## dspy Optimization

`RLM::Optimizer::Dspy` converts `RLM::EvalExample` or structured hash examples into `DSPy::Example` instances and
calls a supplied or preset dspy teleprompter with an RLM-backed program.

```ruby
optimization = RLM::Optimizer::Dspy.compile(
  RLM::Signature::Dspy.new(InvoiceExtraction),
  examples: [
    {
      input: { invoice_text: "Invoice total: $42" },
      expected_output: { total_cents: 4200 }
    }
  ],
  teleprompter: your_dspy_teleprompter,
  lm: RLM::Lm::RubyLLM.new(model: "gpt-5-mini")
)
```

The adapter uses the optimizer's native `compile(program, trainset:, valset:)` contract. RLM does not bundle optional
dspy optimizer gems; pass the teleprompter object explicitly or use a named preset when the corresponding optional dspy
optimizer support is available.

```ruby
optimization = RLM::Optimizer::Dspy.compile(
  RLM::Signature::Dspy.new(InvoiceExtraction),
  examples: eval_examples,
  preset: :mipro_v2_light,
  metric: ->(example, prediction) { prediction.total_cents == example.expected_values[:total_cents] },
  lm: RLM::Lm::RubyLLM.new(model: "gpt-5-mini")
)
```

Built-in preset names are `:mipro_v2_light`, `:mipro_v2_medium`, and `:mipro_v2_heavy`. Register app-specific presets
with `RLM::Optimizer::DspyPresets.register(:name) { |metric:, **options| ... }`.

## Caching

Pass a cache object to reuse identical recursive subcalls, context file reads, read-only tool calls, and skill calls.

```ruby
cache = {}
RLM.predict(InvoiceExtraction, input: input, signatures: [VendorNormalization], cache: cache)
```

Plain Ruby hashes are supported. Cache objects that respond to `fetch` and `write` are also supported.
## Response Protocols
Default responses use `RLM::ResponseProtocol::Tags`; JSON, XML, provider-native JSON, and host-owned BAML adapters are
also available.

```ruby
baml_protocol = RLM::ResponseProtocol::BAML.new(adapter: your_baml_adapter)

RLM.predict(InvoiceExtraction, input: input, response_protocol: baml_protocol)
```

The BAML bridge expects the host adapter to provide `output_instructions` or `instructions`, and `extract(response)` or
`parse(response)`. It normalizes adapter results into RLM's `{ type:, content: }` response protocol contract without
adding a BAML dependency to the gem.

## Telemetry

`RLM::Telemetry` records `rlm.run` and `rlm.lm_call` spans through any tracer responding to `in_span`; without a tracer
it is a no-op. If `opentelemetry-api` is configured, the default tracer is `OpenTelemetry.tracer_provider.tracer("rlm-rb")`.

When `ActiveSupport::Notifications` is loaded, the same names emit as notifications. `RLM::Telemetry::Dspy` forwards
spans through dspy observability, including Langfuse when configured there.
