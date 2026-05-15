# frozen_string_literal: true

module RLM
  module Optimizer
    class DspyProgram
      attr_reader :signature, :predictor, :predict_options, :signature_class

      def initialize(signature, predictor: nil, predict_options: {})
        @signature = signature
        @predictor = predictor || default_predictor
        @predict_options = predict_options
        @signature_class = resolve_signature_class(signature)
      end

      def call(**input)
        result = predictor.call(signature, input: input, **predict_options)
        result.output
      end

      def dup_for_thread
        self
      end

      private

      def resolve_signature_class(candidate)
        return candidate.signature_class if candidate.respond_to?(:signature_class)
        return candidate if defined?(::DSPy::Signature) && candidate.is_a?(Class) && candidate < ::DSPy::Signature

        nil
      end

      def default_predictor
        RLM.respond_to?(:predict) ? RLM.method(:predict) : raise(ArgumentError, "predictor is required")
      end
    end
  end
end
