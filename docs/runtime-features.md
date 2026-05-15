# Runtime Features

This guide covers the plain Ruby runtime features around traces, tools, skills, evals, optimization, caching, and
telemetry.

## Trace Stores

Any `trace_store` object only needs to respond to `#call(result)`. `RLM::TraceStore` formalizes that contract and
`RLM::TraceStore::Memory` provides a small in-memory store for tests, scripts, and local eval collection.

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

Replay a stored trace into a terminal `RLM::Result` without making provider calls:

```ruby
replayed = RLM::TraceReplay.result(result.trace)
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

`RLM::ToolRegistry` only accepts tools whose category is `:read_only`. A `tool_authorizer` callable can deny a
read-only call before execution. Write-capable tools remain a future milestone.

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
| `RLM::Skills::PDF` | `pdf_info(handle)`, `pdf_text_preview(handle, bytes: 4096)` |
| `RLM::Skills::HTML` | `html_text(handle)`, `html_links(handle)` |

The PDF skill is metadata/text-preview only. The HTML skill is static extraction only and does not run a browser,
JavaScript, or network requests.

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
calls a supplied dspy teleprompter with an RLM-backed program.

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
dspy optimizer gems; pass the teleprompter object explicitly.

## Caching

Pass a cache object to reuse identical recursive subcalls, context file reads, read-only tool calls, and skill calls.

```ruby
cache = {}
RLM.predict(InvoiceExtraction, input: input, signatures: [VendorNormalization], cache: cache)
```

Plain Ruby hashes are supported. Cache objects that respond to `fetch` and `write` are also supported.

## Telemetry

`RLM::Telemetry` is dependency-free. When given a tracer object that responds to `in_span`, it records `rlm.run` and
`rlm.lm_call` spans. Without a tracer, it is a no-op. If `opentelemetry-api` is present and configured, the default
telemetry object uses `OpenTelemetry.tracer_provider.tracer("rlm-rb")`.
