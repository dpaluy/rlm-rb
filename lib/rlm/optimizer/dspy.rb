# frozen_string_literal: true

require "dspy"

require_relative "../eval_example"
require_relative "dspy_program"
require_relative "dspy_presets"

module RLM
  module Optimizer
    class Dspy
      attr_reader :signature, :teleprompter, :examples, :valset, :program, :predictor, :predict_options

      def self.compile(
        signature,
        examples:,
        teleprompter: nil,
        preset: nil,
        metric: nil,
        optimizer_options: {},
        valset: nil,
        program: nil,
        predictor: nil,
        **predict_options
      )
        new(
          signature,
          examples: examples,
          teleprompter: teleprompter || DspyPresets.build(preset, metric: metric, **optimizer_options),
          valset: valset,
          program: program,
          predictor: predictor,
          predict_options: predict_options
        ).compile
      end

      def initialize(
        signature,
        examples:,
        teleprompter:,
        valset: nil,
        program: nil,
        predictor: nil,
        predict_options: {}
      )
        @signature = signature
        @teleprompter = teleprompter
        @examples = Array(examples)
        @valset = valset
        @program = program || DspyProgram.new(signature, predictor: predictor, predict_options: predict_options)
        @predictor = predictor
        @predict_options = predict_options
      end

      def compile
        teleprompter.compile(program, trainset: dspy_examples(examples), valset: normalized_valset)
      end

      private

      def normalized_valset
        return nil if valset.nil?

        dspy_examples(Array(valset))
      end

      def dspy_examples(candidates)
        candidates.map { |candidate| dspy_example(candidate) }
      end

      def dspy_example(candidate)
        return candidate if candidate.is_a?(::DSPy::Example)

        payload = example_payload(candidate)
        ::DSPy::Example.new(
          signature_class: signature_class,
          input: symbolize_keys(payload.fetch(:input)),
          expected: symbolize_keys(payload.fetch(:expected)),
          id: payload[:id],
          metadata: symbolize_keys(payload[:metadata] || {})
        )
      end

      def example_payload(candidate)
        {
          id: value_for(candidate, :id),
          input: required_value(candidate, :input),
          expected: expected_value(candidate),
          metadata: value_for(candidate, :metadata)
        }
      end

      def expected_value(candidate)
        value_for(candidate, :expected) ||
          value_for(candidate, :expected_output) ||
          value_for(candidate, :output) ||
          raise(ArgumentError, "dspy optimizer examples require expected output")
      end

      def required_value(candidate, key)
        value_for(candidate, key) || raise(ArgumentError, "dspy optimizer examples require #{key}")
      end

      def value_for(candidate, key)
        return candidate.public_send(key) if candidate.respond_to?(key)
        return candidate[key] if candidate.respond_to?(:key?) && candidate.key?(key)

        string_key = key.to_s
        candidate[string_key] if candidate.respond_to?(:key?) && candidate.key?(string_key)
      end

      def signature_class
        program.signature_class || raise(ArgumentError, "dspy optimizer requires a DSPy signature class")
      end

      def symbolize_keys(hash)
        hash.to_h.transform_keys(&:to_sym)
      end
    end
  end
end
