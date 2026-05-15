# frozen_string_literal: true

module RuntimeBridgeFixtures
  class LookupVendor < RLM::Tool
    input_schema vendor_id: :integer
    output_schema id: :integer, name: :string

    def call(vendor_id:)
      { id: vendor_id, name: "Acme" }
    end
  end

  class WriteTool < RLM::Tool
    category :write_allowed

    def call
      { ok: true }
    end
  end

  FakeRuntime = Struct.new(:calls, :max_depth) do
    def predict_subcall(signature, input, depth:)
      raise RLM::BudgetExceededError, "max_recursion_depth exceeded" if max_depth && depth > max_depth

      calls << { signature: signature, input: input, depth: depth }
      { summary: "sub result" }
    end
  end

  AccountingRuntime = Struct.new(:attempts, :raise_budget) do
    def record_tool_attempt!
      self.attempts += 1
      raise RLM::BudgetExceededError, "max_tool_calls exceeded" if raise_budget
    end

    def record_submitted_output(output)
      @submitted_output = output
    end

    attr_reader :submitted_output
  end

  FakeSignature = Class.new do
    def self.name = "FakeSignature"
    def self.description = "Fake test signature"
    def self.input_fields = { text: :string }
    def self.output_fields = { summary: :string }
    def self.validate_input(input) = input.key?(:text) || input.key?("text") ? [] : ["text is required"]
    def self.validate_output(output) = output.key?(:summary) || output.key?("summary") ? [] : ["summary is required"]
  end

  def build_bridge(runtime: nil, context: RLM::Context.new, trace: RLM::Trace.new, tools: [], signatures: {}, depth: 0)
    RLM::Runtime::Bridge.new(
      runtime: runtime,
      context: context,
      trace: trace,
      tools: tools,
      signatures: signatures,
      depth: depth
    )
  end
end
