# frozen_string_literal: true

require "dspy"

module RLM
  class Telemetry
    class Dspy
      def initialize(context: ::DSPy::Context)
        @context = context
      end

      def in_span(name, attributes: {}, &)
        return yield unless context.respond_to?(:with_span)

        context.with_span(operation: name, **span_attributes(attributes), &)
      end

      private

      attr_reader :context

      def span_attributes(attributes)
        observation_attributes.merge(prefixed_attributes(attributes))
      end

      def observation_attributes
        return {} unless defined?(::DSPy::ObservationType::Span)

        ::DSPy::ObservationType::Span.langfuse_attributes
      end

      def prefixed_attributes(attributes)
        attributes.to_h.transform_keys { |key| "rlm.#{key}" }
      end
    end
  end
end
