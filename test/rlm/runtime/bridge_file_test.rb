# frozen_string_literal: true

require "test_helper"
require_relative "bridge_fixtures"

class RLM::Runtime::BridgeFileTest < Minitest::Test
  include RuntimeBridgeFixtures

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

  def test_read_file_rejects_actual_content_over_file_byte_limit
    file = RLM::File.new(
      filename: "stale.txt",
      content_type: "text/plain",
      size_bytes: 1,
      source: { kind: :text, text: "hello" }
    )
    bridge = build_bridge(context: RLM::Context.new(files: [file]), limits: RLM::Limits.new(max_file_bytes: 4))

    assert_raises(RLM::BudgetExceededError) do
      bridge.read_file("file_1")
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

  def test_submit_forwards_output_to_runtime
    runtime = AccountingRuntime.new(0, false)
    bridge = build_bridge(runtime: runtime)

    bridge.submit({ total: 12 })

    assert_equal({ total: 12 }, runtime.submitted_output)
  end
end
