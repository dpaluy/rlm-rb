# frozen_string_literal: true

require "test_helper"

class RLM::Sandbox::UnsafeInProcessTest < Minitest::Test
  Bridge = Struct.new(:submitted, :logs) do
    def submit(output)
      self.submitted = output
    end

    def log(message)
      logs << message
    end

    def read_file(handle)
      "contents for #{handle}"
    end

    def list_files
      [{ handle: "file_1", filename: "notes.txt" }]
    end

    def predict(signature, input)
      { signature: signature, input: input }
    end

    def tool(name, input)
      { tool: name, input: input }
    end
  end

  def test_exec_requires_prepare
    sandbox = RLM::Sandbox::UnsafeInProcess.new

    assert_raises(RLM::SandboxError) do
      sandbox.exec("submit({})")
    end
  end

  def test_exec_evaluates_code_against_runtime_bridge
    bridge = Bridge.new(nil, [])
    sandbox = prepared_sandbox(bridge: bridge)

    result = sandbox.exec('log("started"); submit({ total: 12 })')

    assert result.ok?
    assert_equal({ total: 12 }, bridge.submitted)
    assert_equal ["started"], bridge.logs
  end

  def test_exec_exposes_runtime_helpers
    bridge = Bridge.new(nil, [])
    sandbox = prepared_sandbox(bridge: bridge)

    code = <<~RUBY
      file = read_file("file_1")
      files = list_files
      sub = predict("SubSignature", { text: file })
      tool_result = tool("Lookup", { id: 7 })
      submit({ files: files, sub: sub, tool: tool_result })
    RUBY

    result = sandbox.exec(code)

    assert result.ok?
    assert_equal "contents for file_1", bridge.submitted[:sub][:input][:text]
    assert_equal "Lookup", bridge.submitted[:tool][:tool]
  end

  def test_captures_stdout_and_stderr
    sandbox = prepared_sandbox

    result = sandbox.exec('$stdout.puts "hello"; $stderr.puts "warn"')

    assert result.ok?
    assert_equal "hello\n", result.stdout
    assert_equal "warn\n", result.stderr
  end

  def test_wraps_runtime_errors
    sandbox = prepared_sandbox

    result = sandbox.exec('raise "boom"')

    refute result.ok?
    assert_equal :error, result.status
    assert_instance_of RuntimeError, result.error
    assert_includes result.stderr, "boom"
  end

  def test_restores_global_streams_after_runtime_errors
    sandbox = prepared_sandbox
    original_stdout = $stdout
    original_stderr = $stderr

    sandbox.exec('$stdout.puts "before"; raise "boom"')

    assert_same original_stdout, $stdout
    assert_same original_stderr, $stderr
  end

  def test_cleanup_resets_prepared_state
    sandbox = prepared_sandbox
    sandbox.cleanup

    assert_raises(RLM::SandboxError) do
      sandbox.exec("submit({})")
    end
  end

  private

  def prepared_sandbox(bridge: Bridge.new(nil, []))
    sandbox = RLM::Sandbox::UnsafeInProcess.new
    sandbox.prepare(context: RLM::Context.new, tools: [], skills: [], runtime_bridge: bridge)
    sandbox
  end
end
