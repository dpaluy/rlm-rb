# frozen_string_literal: true

require "test_helper"

class RLM::ResultTest < Minitest::Test
  def test_success
    trace = RLM::Trace.new
    result = RLM::Result.new(trace: trace, status: :completed, output: { ok: true })
    assert result.success?
    refute result.needs_review?
    refute result.failed?
  end

  def test_needs_review
    result = RLM::Result.new(trace: RLM::Trace.new, status: :needs_review)
    assert result.needs_review?
    refute result.success?
    refute result.failed?
  end

  def test_failure_statuses
    %i[failed_validation budget_exceeded sandbox_error tool_error provider_error aborted].each do |status|
      result = RLM::Result.new(trace: RLM::Trace.new, status: status)
      assert result.failed?, "expected #{status} to be failed?"
    end
  end

  def test_unknown_status_raises
    assert_raises(ArgumentError) do
      RLM::Result.new(trace: RLM::Trace.new, status: :nope)
    end
  end

  def test_to_h_includes_trace_id
    trace = RLM::Trace.new(id: "abc")
    result = RLM::Result.new(trace: trace, status: :completed, output: { v: 1 })
    h = result.to_h
    assert_equal "abc", h[:trace_id]
    assert_equal({ v: 1 }, h[:output])
    assert_equal :completed, h[:status]
  end
end
