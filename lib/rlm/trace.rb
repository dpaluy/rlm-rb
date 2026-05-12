# frozen_string_literal: true

require "json"
require "securerandom"
require "time"

module RLM
  class Trace
    EVENT_TYPES = %i[
      run_started
      root_prompt_created
      root_lm_called
      code_generated
      code_executed
      file_read
      tool_called
      sub_lm_called
      validation_attempted
      validation_failed
      budget_checked
      run_completed
      run_failed
    ].freeze

    attr_reader :id, :events, :started_at

    def initialize(id: SecureRandom.uuid, clock: Time.method(:now))
      @id = id
      @events = []
      @clock = clock
      @started_at = clock.call
    end

    def record(type, payload = {})
      raise ArgumentError, "Unknown trace event type: #{type.inspect}" unless EVENT_TYPES.include?(type)

      events << { type: type, payload: payload, at: @clock.call.iso8601(6) }
      self
    end

    def steps
      events.select { |e| %i[code_generated code_executed].include?(e[:type]) }
    end

    def llm_calls
      events.select { |e| %i[root_lm_called sub_lm_called].include?(e[:type]) }
    end

    def tool_calls
      events.select { |e| e[:type] == :tool_called }
    end

    def files_read
      events.select { |e| e[:type] == :file_read }
    end

    def validation_errors
      events.select { |e| e[:type] == :validation_failed }
    end

    def cost_cents
      llm_calls.sum { |e| e[:payload][:cost_cents].to_i }
    end

    def duration_ms
      return 0 if events.empty?

      ((@clock.call - @started_at) * 1000).to_i
    end

    def to_h
      {
        id: id,
        started_at: started_at.iso8601(6),
        events: events
      }
    end

    def to_json(*)
      JSON.generate(to_h, *)
    end

    def to_ndjson
      events.map { |e| JSON.generate(e) }.join("\n")
    end
  end
end
