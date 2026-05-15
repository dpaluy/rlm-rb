# frozen_string_literal: true

module RLM
  module Sandbox
    class Subprocess < Base
      module WorkerSource
        TEMPLATE_PATH = ::File.expand_path("worker_template.rb.template", __dir__)

        module_function

        def build(stdout_limit_bytes:, stderr_limit_bytes:)
          ::File.read(TEMPLATE_PATH)
                .gsub("STDOUT_LIMIT_BYTES", stdout_limit_bytes.to_s)
                .gsub("STDERR_LIMIT_BYTES", stderr_limit_bytes.to_s)
        end
      end
    end
  end
end
