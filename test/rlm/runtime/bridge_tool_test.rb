# frozen_string_literal: true

require "test_helper"
require_relative "bridge_fixtures"

class RLM::Runtime::BridgeToolTest < Minitest::Test
  include RuntimeBridgeFixtures

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

  def test_tool_executes_registry_entry
    registry = RLM::ToolRegistry.new([LookupVendor])
    bridge = build_bridge(tools: registry)

    assert_equal({ id: 9, name: "Acme" }, bridge.tool("LookupVendor", { vendor_id: 9 }))
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

  def test_tool_validates_input_schema_before_execution
    bridge = build_bridge(tools: [LookupVendor])

    error = assert_raises(RLM::ToolError) do
      bridge.tool("LookupVendor", { vendor_id: "bad" })
    end

    assert_includes error.message, "input.vendor_id must be integer"
  end

  def test_tool_validates_output_schema_after_execution
    bad_tool = Class.new(RLM::Tool) do
      def self.registry_name = "BadLookup"

      output_schema name: :string

      def call
        { name: 1 }
      end
    end
    bridge = build_bridge(tools: [bad_tool])

    error = assert_raises(RLM::ToolError) { bridge.tool("BadLookup", {}) }

    assert_includes error.message, "output.name must be string"
  end

  def test_tool_authorizer_can_deny_read_only_tool_execution
    authorizer = ->(tool:, input:, context:) { tool != LookupVendor || input[:vendor_id] == 1 || context.nil? }
    bridge = build_bridge(tools: [LookupVendor], tool_authorizer: authorizer)

    error = assert_raises(RLM::ToolError) do
      bridge.tool("LookupVendor", { vendor_id: 7 })
    end

    assert_includes error.message, "not authorized"
  end

  def test_tool_authorizer_receives_tool_input_and_context
    calls = []
    context = RLM::Context.new(inputs: { account_id: 1 })
    authorizer = lambda do |**payload|
      calls << payload
      true
    end
    bridge = build_bridge(context: context, tools: [LookupVendor], tool_authorizer: authorizer)

    bridge.tool("LookupVendor", { vendor_id: 7 })

    assert_equal LookupVendor, calls.first[:tool]
    assert_equal({ vendor_id: 7 }, calls.first[:input])
    assert_same context, calls.first[:context]
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
end
