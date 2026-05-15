# frozen_string_literal: true

require "test_helper"

class RLM::ReviewTest < Minitest::Test
  def test_route_enqueues_result_that_matches_default_policy
    queue = RLM::Review::MemoryQueue.new
    result = review_result(:needs_review)

    item = RLM::Review.route(result, queue: queue, metadata: { source: "test" })

    assert_equal item, queue.pending.first
    assert_equal [:needs_review], item.reasons
    assert_equal({ source: "test" }, item.metadata)
    assert_equal result.trace.id, item.to_h[:trace_id]
  end

  def test_route_skips_completed_result
    queue = RLM::Review::MemoryQueue.new

    item = RLM::Review.route(review_result(:completed), queue: queue)

    assert_nil item
    assert_empty queue.all
  end

  def test_policy_can_include_custom_predicate
    policy = RLM::Review::Policy.new(statuses: [], predicate: ->(result) { result.cost_cents > 100 })

    reasons = policy.reasons_for(review_result(:completed, cost_cents: 101))

    assert_equal [:custom_policy], reasons
  end

  def test_memory_queue_resolves_review_items
    queue = RLM::Review::MemoryQueue.new
    item = queue.enqueue(review_result(:failed_validation), reasons: [:validation_failed])

    resolved = queue.resolve(item.id, decision: :approved, reviewer: "alice", notes: "ok")

    refute resolved.pending?
    assert_empty queue.pending
    assert_equal :approved, resolved.status
    assert_equal "alice", resolved.reviewer
    assert_equal "ok", resolved.notes
  end

  private

  def review_result(status, cost_cents: 0)
    RLM::Result.new(
      trace: RLM::Trace.new(id: "trace-#{status}"),
      status: status,
      cost_cents: cost_cents,
      validation_errors: status == :failed_validation ? ["bad output"] : []
    )
  end
end
