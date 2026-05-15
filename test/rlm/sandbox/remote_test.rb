# frozen_string_literal: true

require "test_helper"

class RLM::Sandbox::RemoteTest < Minitest::Test
  class EchoClient
    attr_reader :requests

    def initialize(exec_response: nil)
      @requests = []
      @exec_response = exec_response || {
        "status" => "ok",
        "stdout" => "done",
        "stderr" => "",
        "exit_code" => 0,
        "duration_ms" => 12,
        "events" => [{ "type" => "submitted", "output" => { "ok" => true } }]
      }
    end

    def call(operation, payload)
      requests << [operation, payload]
      return { session_id: "remote-1" } if operation == :prepare
      return @exec_response if operation == :exec

      { ok: true }
    end
  end

  class NamedSkill < RLM::Skill
    registry_name "named"
    description "Named helper."
    helper "named()", description: "Return a name."
  end

  class LookupTool < RLM::Tool
    description "Lookup something."
    input_schema id: :integer
    output_schema name: :string
  end

  def test_requires_prepare_before_exec
    sandbox = RLM::Sandbox::Remote.new(client: EchoClient.new)

    assert_raises(RLM::SandboxError) { sandbox.exec("submit({})") }
  end

  def test_prepare_sends_manifest_payload_to_remote_client
    client = EchoClient.new
    sandbox = RLM::Sandbox::Remote.new(client: client)

    sandbox.prepare(**prepare_options)

    operation, payload = client.requests.first
    assert_equal :prepare, operation
    assert_equal "remote-1", sandbox.session_id
    assert_prepare_payload(payload)
  end

  def assert_prepare_payload(payload)
    assert_equal "file_1", payload.fetch(:context).fetch(:files).first.fetch(:handle)
    assert_equal "LookupTool", payload.fetch(:tools).first.fetch(:name)
    assert_equal "named", payload.fetch(:skills).first.fetch(:name)
    assert_equal 2, payload.fetch(:limits).fetch(:max_files)
  end

  def test_exec_converts_remote_response_into_execution_result
    client = EchoClient.new
    sandbox = prepared_sandbox(client)

    result = sandbox.exec("submit({ ok: true })")

    assert_instance_of RLM::Sandbox::ExecutionResult, result
    assert_predicate result, :ok?
    assert_equal "done", result.stdout
    assert_equal 12, result.duration_ms
    assert_equal :exec, client.requests[1].first
    assert_equal "remote-1", client.requests[1].last.fetch(:session_id)
  end

  def test_cleanup_sends_remote_cleanup_and_resets_state
    client = EchoClient.new
    sandbox = prepared_sandbox(client)

    sandbox.cleanup

    assert_equal :cleanup, client.requests.last.first
    refute sandbox.prepared?
    assert_nil sandbox.session_id
  end

  def test_remote_error_response_sets_error_result
    client = EchoClient.new(exec_response: { status: :error, stderr: "boom", error: "boom" })
    sandbox = prepared_sandbox(client)

    result = sandbox.exec("raise 'boom'")

    assert_equal :error, result.status
    assert_equal "boom", result.error.message
  end

  private

  def prepared_sandbox(client)
    sandbox = RLM::Sandbox::Remote.new(client: client)
    sandbox.prepare(context: RLM::Context.new, tools: [], skills: [], runtime_bridge: :bridge)
    sandbox
  end

  def prepare_options
    {
      context: RLM::Context.new(files: [RLM::File.from_text("note.txt", "hello")]),
      tools: RLM::ToolRegistry.new([LookupTool]),
      skills: [NamedSkill.new],
      runtime_bridge: :bridge,
      limits: RLM::Limits.new(max_files: 2)
    }
  end
end
