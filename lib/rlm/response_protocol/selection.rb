# frozen_string_literal: true

module RLM
  module ResponseProtocol
    class Selection
      attr_reader :protocols, :reports

      def initialize(protocols:, reports:)
        @protocols = protocols
        @reports = reports
      end

      def best_protocol
        protocols.max_by { |protocol| reports.fetch(protocol).score }
      end

      def best_report
        reports.fetch(best_protocol)
      end

      def scores
        protocols.to_h { |protocol| [protocol_name(protocol), reports.fetch(protocol).score] }
      end

      def to_h
        {
          best_protocol: protocol_name(best_protocol),
          scores: scores,
          reports: reports.to_h { |protocol, report| [protocol_name(protocol), report.to_h] }
        }
      end

      private

      def protocol_name(protocol)
        protocol.name.to_s.split("::").last
      end
    end

    module SelectionOptimizer
      DEFAULT_PROTOCOLS = [Tags, JSON, XML].freeze

      module_function

      def optimize(
        signature,
        examples:,
        metric:,
        protocols: DEFAULT_PROTOCOLS,
        predictor: RLM.method(:predict),
        **options
      )
        normalized = Array(protocols)
        raise ArgumentError, "response protocol optimization requires protocols" if normalized.empty?

        reports = normalized.to_h do |protocol|
          [protocol, Eval.run(
            signature,
            examples: examples,
            metric: metric,
            predictor: predictor,
            **options.merge(response_protocol: protocol)
          )]
        end
        Selection.new(protocols: normalized, reports: reports)
      end
    end
  end
end
