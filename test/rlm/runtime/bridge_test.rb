# frozen_string_literal: true

require "test_helper"

class RLM::Runtime::BridgeTest < Minitest::Test
  class LookupVendor < RLM::Tool
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
    def self.name
      "FakeSignature"
    end

    def self.description
      "Fake test signature"
    end

    def self.input_fields
      { text: :string }
    end

    def self.output_fields
      { summary: :string }
    end

    def self.validate_input(input)
      input.key?(:text) || input.key?("text") ? [] : ["text is required"]
    end

    def self.validate_output(output)
      output.key?(:summary) || output.key?("summary") ? [] : ["summary is required"]
    end
  end

  def test_lists_files_from_context_manifest
    file = RLM::File.from_text("notes.txt", "hello")
    bridge = build_bridge(context: RLM::Context.new(files: [file]))

    handles = bridge.list_files.map { |entry| entry[:handle] }

    assert_equal ["file_1"], handles
  end

  def test_reads_file_by_handle_and_records_trace
    file = RLM::File.from_text("notes.txt", "hello")
    trace = RLM::Trace.new
    bridge = build_bridge(context: RLM::Context.new(files: [file]), trace: trace)

    assert_equal "hello", bridge.read_file("file_1")
    assert_equal :file_read, trace.events.last[:type]
    assert_equal "file_1", trace.events.last[:payload][:handle]
  end

  def test_read_file_rejects_unknown_handle
    bridge = build_bridge

    assert_raises(RLM::ValidationError) do
      bridge.read_file("missing")
    end
  end

  def test_submit_stores_terminal_output_and_records_trace
    trace = RLM::Trace.new
    bridge = build_bridge(trace: trace)

    output = bridge.submit({ total: 12 })

    assert_equal({ total: 12 }, output)
    assert_equal({ total: 12 }, bridge.submitted_output)
    assert_equal :output_submitted, trace.events.last[:type]
  end

  def test_rejects_non_json_serializable_submit_output
    bridge = build_bridge

    assert_raises(RLM::ValidationError) do
      bridge.submit({ callback: -> {} })
    end
  end

  def test_log_records_runtime_message
    trace = RLM::Trace.new
    bridge = build_bridge(trace: trace)

    bridge.log("checking file")

    assert_equal :runtime_logged, trace.events.last[:type]
    assert_equal "checking file", trace.events.last[:payload][:message]
  end

  def test_tool_executes_read_only_tool_instance_and_records_trace
    trace = RLM::Trace.new
    bridge = build_bridge(trace: trace, tools: [LookupVendor.new])

    assert_equal({ id: 7, name: "Acme" }, bridge.tool("LookupVendor", { vendor_id: 7 }))
    assert_equal :tool_called, trace.events.last[:type]
    assert_equal "LookupVendor", trace.events.last[:payload][:tool]
  end

  def test_tool_executes_read_only_tool_class
    bridge = build_bridge(tools: [LookupVendor])

    assert_equal({ id: 8, name: "Acme" }, bridge.tool("LookupVendor", { vendor_id: 8 }))
  end

  def test_tool_rejects_unknown_tool
    bridge = build_bridge

    assert_raises(RLM::ToolError) do
      bridge.tool("MissingTool", {})
    end
  end

  def test_tool_rejects_non_read_only_tool
    bridge = build_bridge(tools: [WriteTool.new])

    assert_raises(RLM::ToolError) do
      bridge.tool("WriteTool", {})
    end
  end

  def test_tool_delegates_attempt_accounting_before_lookup
    runtime = AccountingRuntime.new(0, false)
    bridge = build_bridge(runtime: runtime)

    assert_raises(RLM::ToolError) do
      bridge.tool("MissingTool", {})
    end

    assert_equal 1, runtime.attempts
  end

  def test_tool_budget_error_skips_lookup_and_execution
    runtime = AccountingRuntime.new(0, true)
    bridge = build_bridge(runtime: runtime, tools: [LookupVendor.new])

    error = assert_raises(RLM::BudgetExceededError) do
      bridge.tool("LookupVendor", { vendor_id: 7 })
    end

    assert_includes error.message, "max_tool_calls"
    assert_equal 1, runtime.attempts
  end

  def test_submit_forwards_output_to_runtime
    runtime = AccountingRuntime.new(0, false)
    bridge = build_bridge(runtime: runtime)

    bridge.submit({ total: 12 })

    assert_equal({ total: 12 }, runtime.submitted_output)
  end

  def test_predict_routes_recursive_subcall_and_records_trace
    runtime = FakeRuntime.new([], nil)
    trace = RLM::Trace.new
    bridge = build_bridge(runtime: runtime, trace: trace, signatures: { "FakeSignature" => FakeSignature })

    result = bridge.predict("FakeSignature", { text: "hello" })

    assert_equal({ summary: "sub result" }, result)
    assert_equal [{ signature: FakeSignature, input: { text: "hello" }, depth: 1 }], runtime.calls
    assert_equal :validation_attempted, trace.events.last[:type]
    assert_equal "FakeSignature", trace.events.last[:payload][:signature]
  end

  def test_predict_rejects_invalid_signature_input
    trace = RLM::Trace.new
    bridge = build_bridge(trace: trace, signatures: { "FakeSignature" => FakeSignature })

    error = assert_raises(RLM::ValidationError) do
      bridge.predict("FakeSignature", {})
    end

    event_types = trace.events.map { |event| event[:type] }

    assert_includes error.message, "text is required"
    assert_equal %i[validation_attempted validation_failed], event_types
  end

  def test_predict_rejects_unknown_signature
    bridge = build_bridge(signatures: {})

    assert_raises(RLM::ValidationError) do
      bridge.predict("MissingSignature", {})
    end
  end

  def test_predict_rejects_recursive_depth_exceeded
    runtime = FakeRuntime.new([], 1)
    bridge = build_bridge(
      runtime: runtime,
      signatures: { "FakeSignature" => FakeSignature },
      depth: 2
    )

    assert_raises(RLM::BudgetExceededError) do
      bridge.predict("FakeSignature", { text: "hello" })
    end
  end

  private

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
