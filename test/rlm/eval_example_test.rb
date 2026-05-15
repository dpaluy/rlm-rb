# frozen_string_literal: true

require "test_helper"
require "json"

class RLM::EvalExampleTest < Minitest::Test
  def test_builds_from_result_with_core_fields
    example = RLM::EvalExample.from_result(
      completed_result,
      expected_output: { "total" => 42 },
      metadata: { source: "gold" }
    )

    assert_equal "trace-1", example.id
    assert_equal({ "pdf" => "invoice.pdf" }, example.input)
    assert_equal({ "total" => 42 }, example.output)
    assert_equal({ "total" => 42 }, example.expected_output)
    assert_equal :completed, example.status
  end

  def test_builds_from_result_with_trace_and_metadata
    example = RLM::EvalExample.from_result(
      completed_result,
      expected_output: { "total" => 42 },
      metadata: { source: "gold" }
    )

    assert_equal 7, example.metadata[:cost_cents]
    assert_equal "gold", example.metadata[:source]
    assert_equal 1, example.to_h[:trace][:llm_calls].size
    assert_equal 1, example.to_h[:trace][:tool_calls].size
  end

  def test_builds_from_trace_with_submitted_output
    trace = RLM::Trace.new(id: "trace-2")
    trace.record(:run_started, input: { "question" => "why?" })
    trace.record(:output_submitted, output: { "answer" => "because" })
    trace.record(:run_failed, status: :budget_exceeded)

    example = RLM::EvalExample.from_trace(trace)

    assert_equal({ "question" => "why?" }, example.input)
    assert_equal({ "answer" => "because" }, example.output)
    assert_equal :budget_exceeded, example.status
  end

  def test_to_json_is_parseable
    trace = RLM::Trace.new(id: "trace-3")
    trace.record(:run_started, input: { "x" => 1 })

    parsed = JSON.parse(RLM::EvalExample.from_trace(trace, output: { "y" => 2 }).to_json)

    assert_equal "trace-3", parsed["id"]
    assert_equal 1, parsed["input"]["x"]
    assert_equal 2, parsed["output"]["y"]
  end

  private

  def completed_result
    RLM::Result.new(
      trace: completed_trace,
      status: :completed,
      output: { "total" => 42 },
      cost_cents: 7,
      duration_ms: 12,
      llm_calls: 1,
      iterations: 0
    )
  end

  def completed_trace
    RLM::Trace.new(id: "trace-1").tap do |trace|
      trace.record(:run_started, signature: "Invoice", input: { "pdf" => "invoice.pdf" })
      trace.record(:root_lm_called, signature: "Invoice", cost_cents: 7)
      trace.record(:tool_called, tool: "VendorLookup", input: { "vendor_id" => 1 })
      trace.record(:run_completed, status: :completed)
    end
  end
end
