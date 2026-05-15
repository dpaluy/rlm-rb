# frozen_string_literal: true

require "test_helper"

class RLM::TraceStoreTest < Minitest::Test
  def test_base_store_must_be_implemented
    error = assert_raises(NotImplementedError) do
      RLM::TraceStore.new.store(result_with_trace("trace-1"))
    end

    assert_includes error.message, "must implement #store"
  end

  def test_base_fetch_must_be_implemented
    error = assert_raises(NotImplementedError) { RLM::TraceStore.new.fetch("trace-1") }

    assert_includes error.message, "must implement #fetch"
  end

  def test_call_delegates_to_store
    store = Class.new(RLM::TraceStore) do
      attr_reader :stored

      def store(result)
        @stored = result
      end
    end.new

    result = result_with_trace("trace-1")
    store.call(result)

    assert_same result, store.stored
  end

  private

  def result_with_trace(id)
    RLM::Result.new(trace: RLM::Trace.new(id: id), status: :completed, output: {})
  end
end
