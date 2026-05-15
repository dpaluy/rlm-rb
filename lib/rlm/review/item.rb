# frozen_string_literal: true

require "securerandom"
require "time"

module RLM
  module Review
    class Item
      STATUSES = %i[pending approved rejected corrected].freeze

      attr_reader :id, :result, :reasons, :metadata, :created_at, :status,
                  :reviewer, :notes, :reviewed_at, :decision

      def initialize(result:, reasons:, metadata: {}, id: SecureRandom.uuid, clock: Time.method(:now))
        @id = id
        @result = result
        @reasons = Array(reasons).map(&:to_sym).freeze
        @metadata = metadata.to_h.freeze
        @clock = clock
        @created_at = clock.call
        @status = :pending
      end

      def pending?
        status == :pending
      end

      def resolve(decision:, reviewer: nil, notes: nil)
        decision = decision.to_sym
        raise ArgumentError, "Unknown review decision: #{decision.inspect}" unless STATUSES.include?(decision)
        raise ArgumentError, "Cannot resolve review item as pending" if decision == :pending

        @status = decision
        @decision = decision
        @reviewer = reviewer
        @notes = notes
        @reviewed_at = @clock.call
        self
      end

      def to_h
        {
          id: id,
          trace_id: result.trace&.id,
          result_status: result.status,
          reasons: reasons,
          metadata: metadata,
          status: status,
          decision: decision,
          reviewer: reviewer,
          notes: notes,
          created_at: created_at.iso8601(6),
          reviewed_at: reviewed_at&.iso8601(6)
        }
      end
    end
  end
end
