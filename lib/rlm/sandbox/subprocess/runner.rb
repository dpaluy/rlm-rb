# frozen_string_literal: true

require "json"
require "io/wait"
require "open3"
require "timeout"

require_relative "result_builder"

module RLM
  module Sandbox
    class Subprocess < Base
      class Runner
        def initialize(ruby:, script_path:, workdir:, timeout_seconds:, runtime_bridge:)
          @ruby = ruby
          @script_path = script_path
          @workdir = workdir
          @timeout_seconds = timeout_seconds
          @runtime_bridge = runtime_bridge
        end

        def run(code)
          started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
          run_worker(code, started)
        rescue Timeout::Error => e
          ExecutionResult.new(
            status: :timeout,
            stderr: e.message,
            error: e,
            exit_code: nil,
            duration_ms: duration_ms(started)
          )
        rescue StandardError => e
          ExecutionResult.new(
            status: :error,
            stderr: e.message,
            error: e,
            exit_code: 1,
            duration_ms: duration_ms(started)
          )
        end

        private

        attr_reader :ruby, :script_path, :workdir, :timeout_seconds, :runtime_bridge

        def run_worker(code, started)
          Open3.popen3(
            { "RLM_SUBPROCESS_CODE" => code },
            ruby,
            script_path,
            chdir: workdir
          ) do |stdin, stdout, stderr, wait_thread|
            worker_stderr = read_later(stderr)
            message = read_protocol(stdin, stdout, wait_thread, started)
            exit_code = wait_thread.value.exitstatus

            ResultBuilder.new(
              message: message,
              worker_stderr: worker_stderr.value,
              exit_code: exit_code,
              started: started
            ).build
          end
        end

        def read_protocol(stdin, stdout, wait_thread, started)
          loop do
            enforce_timeout!(wait_thread, started)
            readable = stdout.wait_readable(remaining_seconds(started))
            raise Timeout::Error, "subprocess sandbox timed out after #{timeout_seconds}s" unless readable

            line = stdout.gets
            raise SandboxError, "subprocess sandbox exited without a result" if line.nil?

            message = JSON.parse(line)
            case message["type"]
            when "call"
              write_protocol_response(stdin, message)
            when "done"
              stdin.close unless stdin.closed?
              return message
            else
              raise SandboxError, "unknown subprocess protocol message: #{message["type"].inspect}"
            end
          end
        end

        def write_protocol_response(stdin, message)
          result = runtime_bridge.public_send(message["method"], *Array(message["args"]))
          stdin.puts(JSON.generate(id: message["id"], ok: true, result: result))
          stdin.flush
        rescue StandardError => e
          stdin.puts(JSON.generate(id: message["id"], ok: false, error_class: e.class.name, message: e.message))
          stdin.flush
        end

        def enforce_timeout!(wait_thread, started)
          return unless duration_seconds(started) >= timeout_seconds

          terminate(wait_thread.pid)
          raise Timeout::Error, "subprocess sandbox timed out after #{timeout_seconds}s"
        end

        def remaining_seconds(started)
          [timeout_seconds - duration_seconds(started), 0].max
        end

        def duration_seconds(started)
          Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
        end

        def duration_ms(started)
          (duration_seconds(started) * 1000).round
        end

        def terminate(pid)
          Process.kill("TERM", pid)
          Timeout.timeout(0.2) { Process.wait(pid) }
        rescue Errno::ECHILD, Errno::ESRCH
          nil
        rescue Timeout::Error
          Process.kill("KILL", pid)
        end

        def read_later(io)
          Thread.new do
            io.read.to_s
          rescue IOError
            +""
          end
        end
      end
    end
  end
end
