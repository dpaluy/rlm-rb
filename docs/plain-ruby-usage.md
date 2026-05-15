# Plain Ruby Usage

This guide covers the plain Ruby runtime path: configuration, real RubyLLM calls, dspy signatures, mock tests, and
response protocols. Rails integration remains a v2 milestone.

## Configuration

```ruby
RLM.configure do |config|
  config.root_lm = RLM::Lm::RubyLLM.new(model: "gpt-5-mini")
  config.sub_lm = RLM::Lm::RubyLLM.new(model: "gpt-5-mini")
  config.sandbox = RLM::Sandbox::Subprocess.new(timeout_seconds: 10)
  config.response_protocol = RLM::ResponseProtocol::Tags

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

`RLM::Lm::RubyLLM` creates a fresh `RubyLLM.chat` for each runtime LM call. That keeps RLM prompts standalone and
prevents conversation history from leaking between root and sub-model calls.

## dspy Signatures

```ruby
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

signature = RLM::Signature::Dspy.new(InvoiceExtraction)
```

`RLM::Signature::Dspy` wraps a `DSPy::Signature` class behind RLM's internal signature protocol:

- `description`
- `input_fields`
- `output_fields`
- `validate_input`
- `validate_output`
- `coerce_output`

The adapter derives fields and simple validation from dspy JSON schema metadata. Output coercion normalizes parsed
JSON/hash output to schema keys before validation.

## Prediction

```ruby
result = RLM.predict(
  signature,
  input: {
    invoice_text: "Vendor: Acme\nInvoice: INV-001\nTotal: $100.00",
    vendor_id: 123
  },
  limits: RLM::Limits.new(max_iterations: 8, max_llm_calls: 25)
)

result.output
result.trace
result.cost_cents
result.status
```

Usage metadata is recorded on `:root_lm_called` and `:sub_lm_called` trace events when an adapter exposes it.
RubyLLM cost helpers can return `nil` when model pricing is unknown; RLM records `cost_known: false`, contributes
`0` cents for that call, and cannot enforce unknown provider cost.

## Mock Runtime

```ruby
lm = RLM::Lm::Mock.new(
  responses: ['<rlm-final>{"vendor_name":"Acme","invoice_number":"INV-001","total_cents":10000}</rlm-final>']
)

result = RLM.predict(
  InvoiceExtraction,
  input: { vendor_id: 123 },
  lm: lm,
  sandbox: RLM::Sandbox::UnsafeInProcess.new,
  limits: RLM::Limits.new(max_iterations: 8, max_llm_calls: 25)
)
```

`UnsafeInProcess` is dev/test-only. Production should use an isolated sandbox backend.

## Response Protocols

`RLM::ResponseProtocol::Tags` is the default. It asks models to return exactly one `<rlm-code>` or `<rlm-final>` block.

```ruby
RLM.predict(signature, input: input, response_protocol: RLM::ResponseProtocol::Tags)
```

For models that behave better with a JSON envelope, use `RLM::ResponseProtocol::JSON`:

```ruby
RLM.predict(signature, input: input, response_protocol: RLM::ResponseProtocol::JSON)
```

Use `RLM::ResponseProtocol.optimize(...)` with eval examples to compare tag, JSON, XML, or custom protocols.

The JSON protocol expects one object:

```json
{"type":"final","content":{"result":"final JSON answer"}}
```

or:

```json
{"type":"code","content":"submit({\"result\"=>\"computed\"})"}
```

## Live Example

The gem ships one opt-in live example at `examples/plain_ruby_invoice_extraction.rb`.

```bash
bundle exec ruby examples/plain_ruby_invoice_extraction.rb
```

By default it exits before provider credential checks, LM configuration, or `RLM.predict`, even if provider credentials
are present. To run the live path:

```bash
RLM_RUN_LIVE_EXAMPLE=1 OPENAI_API_KEY="$OPENAI_API_KEY" \
  bundle exec ruby examples/plain_ruby_invoice_extraction.rb
```

Set `RLM_EXAMPLE_MODEL` and `RLM_EXAMPLE_SUB_MODEL` to override the default model.
