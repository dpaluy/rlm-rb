# frozen_string_literal: true

module RLM
  module Review
    class Policy
      DEFAULT_STATUSES = %i[needs_review failed_validation].freeze

      def self.default
        new
      end

      def initialize(statuses: DEFAULT_STATUSES, predicate: nil)
        @statuses = Array(statuses).map(&:to_sym).freeze
        @predicate = predicate
      end

      def review?(result)
        reasons_for(result).any?
      end

      def reasons_for(result)
        reasons = []
        reasons << status_reason(result) if statuses.include?(result.status)
        reasons << :validation_errors if result.validation_errors.any?
        reasons << :custom_policy if predicate&.call(result)
        reasons.compact.uniq
      end

      private

      attr_reader :statuses, :predicate

      def status_reason(result)
        case result.status
        when :needs_review then :needs_review
        when :failed_validation then :validation_failed
        else result.status
        end
      end
    end
  end
end
