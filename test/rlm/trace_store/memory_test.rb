# frozen_string_literal: true

require "test_helper"

class RLM::TraceStore::MemoryTest < Minitest::Test
  def test_stores_and_fetches_results_by_trace_id
    store = RLM::TraceStore::Memory.new
    result = result_with_trace("trace-1")

    store.call(result)

    assert_same result, store.fetch("trace-1")
    assert_equal [result], store.all
  end

  def test_clear_removes_results
    store = RLM::TraceStore::Memory.new
    store.store(result_with_trace("trace-1"))

    store.clear

    assert_empty store.all
  end

  def test_rejects_results_without_trace_id
    store = RLM::TraceStore::Memory.new
    result = RLM::Result.new(trace: nil, status: :completed)

    error = assert_raises(ArgumentError) { store.store(result) }

    assert_includes error.message, "trace id"
  end

  private

  def result_with_trace(id)
    RLM::Result.new(trace: RLM::Trace.new(id: id), status: :completed, output: {})
  end
end
