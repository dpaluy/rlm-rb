# frozen_string_literal: true

require "test_helper"

class RLM::Sandbox::WasmTest < Minitest::Test
  class Runtime
    attr_reader :requests

    def initialize
      @requests = []
    end

    def call(operation, payload)
      requests << [operation, payload]
      return { session_id: "wasm-1" } if operation == :prepare
      return { status: :ok, stdout: "wasm", stderr: "", exit_code: 0, duration_ms: 3 } if operation == :exec

      { ok: true }
    end
  end

  def test_delegates_to_host_owned_wasm_runtime
    runtime = Runtime.new
    sandbox = RLM::Sandbox::Wasm.new(runtime: runtime)

    sandbox.prepare(context: RLM::Context.new, tools: [], skills: [], runtime_bridge: :bridge)
    result = sandbox.exec("submit({ ok: true })")
    sandbox.cleanup

    assert_equal "wasm-1", runtime.requests[1].last.fetch(:session_id)
    assert_equal "wasm", result.stdout
    assert_equal %i[prepare exec cleanup], runtime.requests.map(&:first)
  end
end
