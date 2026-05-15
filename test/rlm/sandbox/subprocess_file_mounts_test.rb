# frozen_string_literal: true

require "test_helper"

class RLM::Sandbox::SubprocessFileMountsTest < Minitest::Test
  Bridge = Struct.new(:submitted) do
    def submit(output)
      self.submitted = output
    end
  end

  def test_prepare_mounts_context_files_under_manifest_sandbox_path
    file = RLM::File.from_text("notes.txt", "hello")
    context = RLM::Context.new(files: [file])
    bridge = Bridge.new
    sandbox = RLM::Sandbox::Subprocess.new

    sandbox.prepare(context: context, tools: [], skills: [], runtime_bridge: bridge, limits: RLM::Limits.new)
    result = sandbox.exec('submit({ content: File.read("rlm_files/file_1/notes.txt") })')

    assert result.ok?
    assert_equal "hello", bridge.submitted["content"]
  ensure
    sandbox&.cleanup
  end

  def test_prepare_cleans_up_workdir_when_mounting_fails
    file = RLM::File.new(
      filename: "stale.txt",
      content_type: "text/plain",
      size_bytes: 1,
      source: { kind: :text, text: "hello" }
    )
    sandbox = RLM::Sandbox::Subprocess.new

    assert_raises(RLM::BudgetExceededError) do
      sandbox.prepare(
        context: RLM::Context.new(files: [file]),
        tools: [],
        skills: [],
        runtime_bridge: Bridge.new,
        limits: RLM::Limits.new(max_file_bytes: 4)
      )
    end
    refute sandbox.prepared?
    assert_nil sandbox.workdir
  end
end
