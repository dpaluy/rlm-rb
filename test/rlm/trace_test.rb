# frozen_string_literal: true

require "test_helper"
require "json"

class RLM::TraceTest < Minitest::Test
  def test_record_appends_event
    trace = RLM::Trace.new
    trace.record(:run_started, signature: "FakeSignature")
    assert_equal 1, trace.events.size
    assert_equal :run_started, trace.events.first[:type]
    assert_equal "FakeSignature", trace.events.first[:payload][:signature]
  end

  def test_record_rejects_unknown_type
    trace = RLM::Trace.new
    assert_raises(ArgumentError) { trace.record(:nonsense) }
  end

  def test_step_filters
    trace = RLM::Trace.new
    trace.record(:run_started)
    trace.record(:code_generated, code: "puts 1")
    trace.record(:code_executed, stdout: "1")
    trace.record(:root_lm_called, cost_cents: 12)
    trace.record(:sub_lm_called, cost_cents: 3)

    assert_equal 2, trace.steps.size
    assert_equal 2, trace.llm_calls.size
    assert_equal 15, trace.cost_cents
  end

  def test_validation_errors_filter
    trace = RLM::Trace.new
    trace.record(:validation_attempted)
    trace.record(:validation_failed, errors: ["bad field"])
    assert_equal 1, trace.validation_errors.size
  end

  def test_event_types_cover_prd_contract
    assert_equal %i[
      run_started
      root_prompt_created
      root_lm_called
      code_generated
      code_executed
      file_read
      tool_called
      sub_lm_called
      output_submitted
      runtime_logged
      validation_attempted
      validation_failed
      budget_checked
      run_completed
      run_failed
    ], RLM::Trace::EVENT_TYPES
  end

  def test_to_h_includes_id_and_events
    trace = RLM::Trace.new(id: "fixed-id")
    trace.record(:run_started)
    payload = trace.to_h
    assert_equal "fixed-id", payload[:id]
    assert_equal 1, payload[:events].size
    assert payload[:started_at]
  end

  def test_to_json_is_parseable
    trace = RLM::Trace.new
    trace.record(:run_started, foo: "bar")
    parsed = JSON.parse(trace.to_json)
    assert_equal "run_started", parsed["events"].first["type"]
    assert_equal "bar", parsed["events"].first["payload"]["foo"]
  end

  def test_to_ndjson_is_line_per_event
    trace = RLM::Trace.new
    trace.record(:run_started)
    trace.record(:run_completed)
    lines = trace.to_ndjson.split("\n")
    assert_equal 2, lines.size
    assert_equal "run_started", JSON.parse(lines.first)["type"]
  end
end
