# frozen_string_literal: true

module RLM
  class Runtime
    module Execution
      private

      def start_run
        trace.record(:run_started, signature: Signature.name_for(signature), input: input)
        validate_root_input!
      end

      def prepare_sandbox
        bridge = Bridge.new(
          runtime: self,
          context: context,
          trace: trace,
          tools: tools,
          signatures: signatures,
          depth: depth
        )
        sandbox.prepare(context: context, tools: tools, skills: skills, runtime_bridge: bridge)
        bridge
      end

      def run_loop(bridge)
        loop do
          ensure_time_budget!
          parsed = call_root_lm
          return complete(parsed.content) if parsed.final?

          execute_code(parsed.content)
          return complete(bridge.submitted_output) unless bridge.submitted_output.nil?
        end
      end

      def execute_code(code)
        ensure_time_budget!
        trace.record(:budget_checked, budget: :iterations, current: iterations, limit: limits.max_iterations)
        raise BudgetExceededError, "max_iterations exceeded" if iterations >= limits.max_iterations

        @iterations += 1
        trace.record(:code_generated, code: code)
        result = sandbox.exec(code)
        ensure_stdout_budget!(result)
        trace.record(:code_executed, result: result.to_h)
        handle_sandbox_result!(result)
      end

      def handle_sandbox_result!(result)
        return if result.ok?

        case result.error
        when BudgetExceededError, ParseError, ToolError
          raise result.error
        else
          raise SandboxError, result.error&.message || result.stderr || "sandbox execution failed"
        end
      end
    end
  end
end
