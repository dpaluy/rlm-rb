# frozen_string_literal: true

module RLM
  module Sandbox
    class Base
      def prepare(context:, tools:, skills:, runtime_bridge:)
        raise NotImplementedError, "#{self.class} must implement #prepare"
      end

      def exec(code)
        raise NotImplementedError, "#{self.class} must implement #exec"
      end

      def cleanup
        raise NotImplementedError, "#{self.class} must implement #cleanup"
      end
    end
  end
end
