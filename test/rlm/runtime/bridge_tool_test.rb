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
end
