# frozen_string_literal: true

require "test_helper"

class RLM::Sandbox::SubprocessTest < Minitest::Test
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
      [{ "handle" => "file_1", "filename" => "notes.txt" }]
    end

    def predict(signature, input)
      { "signature" => signature, "input" => input }
    end

    def tool(name, input)
      { "tool" => name, "input" => input }
    end
  end

  def test_exec_requires_prepare
    sandbox = RLM::Sandbox::Subprocess.new

    assert_raises(RLM::SandboxError) do
      sandbox.exec("submit({})")
    end
  end

  def test_exec_runs_in_child_process_and_proxies_runtime_helpers
    bridge = Bridge.new(nil, [])
    sandbox = prepared_sandbox(bridge: bridge)

    code = <<~RUBY
      log("started")
      file = read_file("file_1")
      files = list_files
      sub = predict("SubSignature", { text: file })
      tool_result = tool("Lookup", { id: 7 })
      submit({ files: files, sub: sub, tool: tool_result })
    RUBY

    result = sandbox.exec(code)

    assert result.ok?
    assert_empty result.stderr
    assert_equal ["started"], bridge.logs
    assert_equal "contents for file_1", bridge.submitted["sub"]["input"]["text"]
    assert_equal "Lookup", bridge.submitted["tool"]["tool"]
  ensure
    sandbox&.cleanup
  end

  def test_captures_stdout_and_stderr
    sandbox = prepared_sandbox

    result = sandbox.exec('$stdout.puts "hello"; $stderr.puts "warn"')

    assert result.ok?
    assert_equal "hello\n", result.stdout
    assert_equal "warn\n", result.stderr
  ensure
    sandbox&.cleanup
  end

  def test_wraps_runtime_errors
    sandbox = prepared_sandbox

    result = sandbox.exec('raise "boom"')

    refute result.ok?
    assert_equal :error, result.status
    assert_instance_of RuntimeError, result.error
    assert_includes result.stderr, "boom"
  ensure
    sandbox&.cleanup
  end

  def test_preserves_bridge_error_classes_for_runtime_handling
    bridge = Bridge.new(nil, [])
    def bridge.predict(*) = raise RLM::BudgetExceededError, "too many subcalls"
    sandbox = prepared_sandbox(bridge: bridge)

    result = sandbox.exec('predict("SubSignature", { text: "hello" })')

    refute result.ok?
    assert_instance_of RLM::BudgetExceededError, result.error
    assert_equal "too many subcalls", result.error.message
  ensure
    sandbox&.cleanup
  end

  def test_timeout_terminates_child_process
    sandbox = prepared_sandbox(timeout_seconds: 0.1)

    result = sandbox.exec("sleep 2")

    assert_equal :timeout, result.status
    assert_instance_of Timeout::Error, result.error
    assert_includes result.stderr, "timed out"
  ensure
    sandbox&.cleanup
  end

  def test_cleanup_removes_workdir_and_resets_prepared_state
    sandbox = prepared_sandbox
    workdir = sandbox.workdir

    assert ::File.directory?(workdir)

    sandbox.cleanup

    refute ::File.exist?(workdir)
    assert_raises(RLM::SandboxError) { sandbox.exec("submit({})") }
  end

  private

  def prepared_sandbox(bridge: Bridge.new(nil, []), timeout_seconds: 5)
    sandbox = RLM::Sandbox::Subprocess.new(timeout_seconds: timeout_seconds)
    sandbox.prepare(context: RLM::Context.new, tools: [], skills: [], runtime_bridge: bridge)
    sandbox
  end
end
