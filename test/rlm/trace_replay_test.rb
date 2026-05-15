# frozen_string_literal: true

require "test_helper"

class RLM::TraceReplayTest < Minitest::Test
  def test_replays_completed_trace_to_result
    trace = RLM::Trace.new(id: "trace-1")
    trace.record(:run_started, input: { text: "hello" })
    trace.record(:root_lm_called, signature: "Root", cost_cents: 2)
    trace.record(:code_generated, code: "submit")
    trace.record(:run_completed, status: :completed, output: { "summary" => "done" })

    result = RLM::TraceReplay.result(trace)

    assert result.success?
    assert_equal({ "summary" => "done" }, result.output)
    assert_equal 2, result.cost_cents
    assert_equal 1, result.llm_calls
    assert_equal 1, result.iterations
  end

  def test_replays_failed_trace_with_error_payload
    trace = RLM::Trace.new(id: "trace-2")
    trace.record(:validation_failed, errors: ["summary is required"])
    trace.record(
      :run_failed,
      status: :failed_validation,
      error: { class: "RLM::ValidationError", message: "summary is required" },
      errors: ["summary is required"]
    )

    result = RLM::TraceReplay.result(trace)

    assert result.failed?
    assert_equal :failed_validation, result.status
    assert_equal "summary is required", result.error.message
    assert_equal "RLM::ValidationError", result.error.error_class
    assert_equal ["summary is required"], result.validation_errors
  end

  def test_replay_uses_last_submitted_output_when_terminal_output_missing
    trace = RLM::Trace.new(id: "trace-3")
    trace.record(:output_submitted, output: { "summary" => "partial" })
    trace.record(:run_failed, status: :budget_exceeded)

    result = RLM::TraceReplay.result(trace)

    assert_equal({ "summary" => "partial" }, result.output)
  end

  def test_replay_requires_terminal_status
    assert_raises(ArgumentError) { RLM::TraceReplay.result(RLM::Trace.new) }
  end
end
