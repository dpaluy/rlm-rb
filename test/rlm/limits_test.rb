# frozen_string_literal: true

require "test_helper"

class RLM::LimitsTest < Minitest::Test
  def test_defaults_match_prd
    limits = RLM::Limits.new
    assert_equal 8, limits.max_iterations
    assert_equal 25, limits.max_llm_calls
    assert_equal 20, limits.max_tool_calls
    assert_equal 120, limits.max_runtime_seconds
    assert_equal 100, limits.max_cost_cents
    assert_equal 1, limits.max_recursion_depth
    assert_equal :needs_review, limits.on_budget_exceeded
  end

  def test_override_individual_limit
    limits = RLM::Limits.new(max_iterations: 4)
    assert_equal 4, limits.max_iterations
    assert_equal 25, limits.max_llm_calls
  end

  def test_unknown_key_raises
    error = assert_raises(ArgumentError) { RLM::Limits.new(banana: 9000) }
    assert_match(/Unknown limit keys: banana/, error.message)
  end

  def test_negative_integer_raises
    assert_raises(ArgumentError) { RLM::Limits.new(max_iterations: -1) }
  end

  def test_invalid_policy_raises
    assert_raises(ArgumentError) { RLM::Limits.new(on_budget_exceeded: :explode) }
  end

  def test_merge_returns_new_instance
    base = RLM::Limits.new
    merged = base.merge(max_cost_cents: 500)
    assert_equal 500, merged.max_cost_cents
    assert_equal 100, base.max_cost_cents
    refute_same base, merged
  end

  def test_to_h_round_trip
    limits = RLM::Limits.new(max_llm_calls: 50)
    assert_equal 50, RLM::Limits.new(**limits.to_h).max_llm_calls
  end
end
