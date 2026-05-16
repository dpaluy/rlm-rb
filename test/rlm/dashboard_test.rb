# frozen_string_literal: true

require "test_helper"

class RLM::DashboardTest < Minitest::Test
  def test_summary_counts_statuses_and_runtime_totals_for_results
    summary = RLM::Dashboard.summary([
                                       result("trace-1", :completed, cost_cents: 10, duration_ms: 100, llm_calls: 2),
                                       result("trace-2", :needs_review, cost_cents: 5, duration_ms: 200, llm_calls: 4)
                                     ])

    assert_equal 2, summary[:total_runs]
    assert_equal({ "completed" => 1, "needs_review" => 1 }, summary[:status_counts])
    assert_equal 15, summary[:total_cost_cents]
    assert_equal 150.0, summary[:average_duration_ms]
    assert_equal 3.0, summary[:average_llm_calls]
    recent_trace_ids = summary[:recent_runs].map { |run| run[:trace_id] }

    assert_equal %w[trace-1 trace-2], recent_trace_ids
  end

  def test_summary_accepts_hashes_and_record_like_objects
    record = Struct.new(:trace_id, :status, :cost_cents, :duration_ms, :llm_calls, :iterations, :output)
                   .new("trace-2", "failed_validation", 3, 25, 1, 1, { "ok" => false })

    summary = RLM::Dashboard.summary([
                                       { trace_id: "trace-1", status: "completed", cost_cents: 7, duration_ms: 75 },
                                       record
                                     ])

    assert_equal({ "completed" => 1, "failed_validation" => 1 }, summary[:status_counts])
    assert_equal 10, summary[:total_cost_cents]
    assert_equal({ "ok" => false }, summary[:recent_runs].last[:output])
  end

  def test_summary_handles_empty_records
    summary = RLM::Dashboard.summary([])

    assert_equal 0, summary[:total_runs]
    assert_equal({}, summary[:status_counts])
    assert_equal 0, summary[:average_duration_ms]
  end

  private

  def result(trace_id, status, cost_cents:, duration_ms:, llm_calls:)
    RLM::Result.new(
      trace: RLM::Trace.new(id: trace_id),
      status: status,
      output: { ok: true },
      cost_cents: cost_cents,
      duration_ms: duration_ms,
      llm_calls: llm_calls,
      iterations: 1
    )
  end
end
