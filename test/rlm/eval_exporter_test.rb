# frozen_string_literal: true

require "test_helper"
require "json"

class RLM::EvalExporterTest < Minitest::Test
  def test_exports_results_to_jsonl
    result = RLM::Result.new(
      trace: trace_with_input("trace-1", { "task" => "a" }),
      status: :completed,
      output: { "answer" => "A" }
    )

    line = RLM::EvalExporter.to_jsonl(result, metadata: { split: "train" })
    parsed = JSON.parse(line)

    assert_equal "trace-1", parsed["id"]
    assert_equal "a", parsed["input"]["task"]
    assert_equal "A", parsed["output"]["answer"]
    assert_equal "train", parsed["metadata"]["split"]
  end

  def test_exports_multiple_records_one_per_line
    traces = [
      trace_with_input("trace-1", { "task" => "a" }),
      trace_with_input("trace-2", { "task" => "b" })
    ]

    lines = RLM::EvalExporter.to_jsonl(traces).split("\n")

    assert_equal 2, lines.size
    assert_equal "trace-1", JSON.parse(lines[0])["id"]
    assert_equal "trace-2", JSON.parse(lines[1])["id"]
  end

  def test_rejects_unknown_records
    error = assert_raises(ArgumentError) { RLM::EvalExporter.examples(Object.new) }

    assert_includes error.message, "expected RLM::Result or RLM::Trace"
  end

  private

  def trace_with_input(id, input)
    RLM::Trace.new(id: id).tap do |trace|
      trace.record(:run_started, input: input)
      trace.record(:run_completed, status: :completed)
    end
  end
end
