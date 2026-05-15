# frozen_string_literal: true

module RLM
  class TraceStore
    def call(result)
      store(result)
    end

    def store(_result)
      raise NotImplementedError, "#{self.class} must implement #store"
    end

    def fetch(_trace_id)
      raise NotImplementedError, "#{self.class} must implement #fetch"
    end
  end
end
