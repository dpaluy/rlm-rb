# frozen_string_literal: true

require "test_helper"

class RLM::Sandbox::MockTest < Minitest::Test
  def test_exec_requires_prepare
    sandbox = RLM::Sandbox::Mock.new
    assert_raises(RLM::SandboxError) { sandbox.exec("puts 1") }
  end

  def test_prepare_then_exec_returns_ok_when_no_handler
    sandbox = RLM::Sandbox::Mock.new
    sandbox.prepare(context: RLM::Context.new, tools: [], skills: [], runtime_bridge: :stub)
    result = sandbox.exec("puts 1 + 1")
    assert_instance_of RLM::Sandbox::ExecutionResult, result
    assert result.ok?
    assert_includes sandbox.executed_code, "puts 1 + 1"
  end

  def test_handler_receives_code_and_bridge
    received = []
    handler = lambda do |code, context:, bridge:|
      received << [code, context, bridge]
      RLM::Sandbox::ExecutionResult.new(stdout: "handled")
    end

    sandbox = RLM::Sandbox::Mock.new(handler: handler)
    context = RLM::Context.new
    sandbox.prepare(context: context, tools: [], skills: [], runtime_bridge: :bridge)
    result = sandbox.exec("submit(:done)")

    assert_equal "handled", result.stdout
    assert_equal 1, received.size
    assert_equal "submit(:done)", received.first[0]
    assert_same context, received.first[1]
    assert_equal :bridge, received.first[2]
  end

  def test_handler_returning_non_execution_result_is_wrapped
    handler = ->(_code, **) { "raw string" }
    sandbox = RLM::Sandbox::Mock.new(handler: handler)
    sandbox.prepare(context: RLM::Context.new, tools: [], skills: [], runtime_bridge: nil)
    result = sandbox.exec("noop")
    assert_equal "raw string", result.stdout
    assert result.ok?
  end

  def test_cleanup_resets_state
    sandbox = RLM::Sandbox::Mock.new
    sandbox.prepare(context: RLM::Context.new, tools: [], skills: [], runtime_bridge: nil)
    sandbox.exec("noop")
    sandbox.cleanup
    refute sandbox.prepared?
    assert_empty sandbox.executed_code
  end
end
