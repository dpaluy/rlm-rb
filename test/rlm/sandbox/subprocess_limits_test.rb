# frozen_string_literal: true

require "test_helper"

class RLM::Sandbox::SubprocessLimitsTest < Minitest::Test
  Bridge = Struct.new(:submitted, :logs)

  def test_prepare_rejects_too_many_context_files
    files = [
      RLM::File.from_text("a.txt", "a"),
      RLM::File.from_text("b.txt", "b")
    ]

    assert_prepare_budget_error(context: RLM::Context.new(files: files), limits: RLM::Limits.new(max_files: 1))
  end

  def test_prepare_rejects_oversized_declared_context_file
    file = RLM::File.from_text("large.txt", "hello")

    assert_prepare_budget_error(context: RLM::Context.new(files: [file]), limits: RLM::Limits.new(max_file_bytes: 4))
  end

  def test_prepare_rejects_oversized_context_inputs
    assert_prepare_budget_error(
      context: RLM::Context.new(inputs: { body: "hello" }),
      limits: RLM::Limits.new(max_input_bytes: 4)
    )
  end

  private

  def assert_prepare_budget_error(context:, limits:)
    sandbox = RLM::Sandbox::Subprocess.new

    assert_raises(RLM::BudgetExceededError) do
      sandbox.prepare(
        context: context,
        tools: [],
        skills: [],
        runtime_bridge: Bridge.new(nil, []),
        limits: limits
      )
    end
    refute sandbox.prepared?
    assert_nil sandbox.context
  end
end
