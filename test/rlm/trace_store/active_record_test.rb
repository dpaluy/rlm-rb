# frozen_string_literal: true

require "test_helper"

class RLM::TraceStore::ActiveRecordTest < Minitest::Test
  def test_store_persists_result_attributes
    record_class = FakeRecordClass.new
    store = RLM::TraceStore::ActiveRecord.new(record_class: record_class)
    result = result_with_trace("trace-1")

    record = store.store(result)

    assert_same record, record_class.records.first
    assert_equal "trace-1", record.trace_id
    assert_equal "completed", record.status
    assert_equal({ answer: 42 }, record.output)
    assert_equal({ id: "trace-1", started_at: result.trace.to_h[:started_at], events: [] }, record.trace)
  end

  def test_fetch_looks_up_by_trace_id
    record_class = FakeRecordClass.new
    store = RLM::TraceStore::ActiveRecord.new(record_class: record_class)
    record = store.store(result_with_trace("trace-2"))

    assert_same record, store.fetch("trace-2")
  end

  def test_store_requires_trace_id
    result = RLM::Result.new(trace: nil, status: :completed)
    store = RLM::TraceStore::ActiveRecord.new(record_class: FakeRecordClass.new)

    assert_raises(ArgumentError) { store.store(result) }
  end

  private

  def result_with_trace(trace_id)
    RLM::Result.new(
      trace: RLM::Trace.new(id: trace_id),
      status: :completed,
      output: { answer: 42 },
      cost_cents: 3,
      duration_ms: 50,
      llm_calls: 2,
      iterations: 1
    )
  end

  class FakeRecordClass
    attr_reader :records

    def initialize
      @records = []
    end

    def create!(attributes)
      FakeRecord.new(attributes).tap { |record| records << record }
    end

    def find_by(trace_id:)
      records.find { |record| record.trace_id == trace_id }
    end
  end

  class FakeRecord
    def initialize(attributes)
      @attributes = attributes
    end

    def method_missing(name, *, &)
      return @attributes.fetch(name) if @attributes.key?(name)

      super
    end

    def respond_to_missing?(name, _include_private = false)
      @attributes.key?(name) || super
    end
  end
end
