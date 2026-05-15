# frozen_string_literal: true

require "json"
require "rbconfig"
require "tmpdir"

require "test_helper"

class RLM::Sandbox::DockerTest < Minitest::Test
  Bridge = Struct.new(:submitted, :logs) do
    def submit(output) = self.submitted = output
    def log(message) = logs << message
    def read_file(handle) = "contents for #{handle}"
  end

  def test_exec_requires_prepare
    sandbox = RLM::Sandbox::Docker.new(docker: fake_docker)

    assert_raises(RLM::SandboxError) { sandbox.exec("submit({})") }
  end

  def test_exec_runs_worker_through_docker_cli_and_proxies_helpers
    bridge = Bridge.new(nil, [])
    sandbox = prepared_sandbox(bridge: bridge)

    result = sandbox.exec('log("started"); submit({ text: read_file("file_1") })')

    assert result.ok?
    assert_equal ["started"], bridge.logs
    assert_equal "contents for file_1", bridge.submitted["text"]
    assert_includes docker_args, "--network"
    assert_includes docker_args, "none"
    assert_includes docker_args, "ruby:3.3"
  ensure
    sandbox&.cleanup
  end

  def test_mounts_context_files_in_container_workdir
    bridge = Bridge.new(nil, [])
    file = RLM::File.from_text("notes.txt", "hello")
    context = RLM::Context.new(files: [file])
    sandbox = prepared_sandbox(bridge: bridge, context: context)

    result = sandbox.exec('submit({ content: File.read("rlm_files/file_1/notes.txt") })')

    assert result.ok?
    assert_equal "hello", bridge.submitted["content"]
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

  def prepared_sandbox(bridge: Bridge.new(nil, []), context: RLM::Context.new)
    sandbox = RLM::Sandbox::Docker.new(docker: fake_docker, timeout_seconds: 2)
    sandbox.prepare(context: context, tools: [], skills: [], runtime_bridge: bridge, limits: RLM::Limits.new)
    sandbox
  end

  def fake_docker
    @fake_docker ||= begin
      ENV["RLM_FAKE_DOCKER_ARGS"] = docker_args_path
      @tmpdir = Dir.mktmpdir("rlm-fake-docker-")
      path = ::File.join(@tmpdir, "docker")
      ::File.write(path, fake_docker_source)
      ::File.chmod(0o755, path)
      path
    end
  end

  def docker_args
    JSON.parse(::File.read(docker_args_path))
  end

  def docker_args_path
    @docker_args_path ||= ::File.join(Dir.mktmpdir("rlm-docker-args-"), "args.json")
  end

  def fake_docker_source
    <<~'RUBY'
      #!/usr/bin/env ruby
      require "json"
      require "rbconfig"

      File.write(ENV.fetch("RLM_FAKE_DOCKER_ARGS"), JSON.generate(ARGV))
      volume = ARGV.each_cons(2).find { |flag, _| flag == "-v" }.last
      host_workdir, container_workdir = volume.split(":", 3)
      worker = ARGV.last.sub(/^#{Regexp.escape(container_workdir)}/, host_workdir)
      Dir.chdir(host_workdir) { exec(RbConfig.ruby, worker) }
    RUBY
  end
end
