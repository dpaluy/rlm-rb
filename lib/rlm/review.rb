# frozen_string_literal: true

require_relative "review/item"
require_relative "review/memory_queue"
require_relative "review/policy"

module RLM
  module Review
    module_function

    def route(result, queue:, policy: Policy.default, metadata: {})
      reasons = policy.reasons_for(result)
      return nil if reasons.empty?

      queue.enqueue(result, reasons: reasons, metadata: metadata)
    end
  end
end
