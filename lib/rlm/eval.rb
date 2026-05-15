# frozen_string_literal: true

module RLM
  class Eval
    class ExampleResult
      attr_reader :example, :result, :score, :passed

      def initialize(example:, result:, score:)
        @example = example
        @result = result
        @score = score
        @passed = passed_score?(score)
      end

      def passed?
        passed
      end

      def to_h
        {
          example: example.to_h,
          result: result.to_h,
          score: score,
          passed: passed?
        }
      end

      private

      def passed_score?(value)
        value == true || (value.is_a?(Numeric) && value >= 1)
      end
    end

    class Result
      attr_reader :examples

      def initialize(examples:)
        @examples = examples
      end

      def total = examples.size

      def passed = examples.count(&:passed?)

      def failed = total - passed

      def score
        return 0.0 if examples.empty?

        numeric_scores.sum.to_f / total
      end

      def success?
        total.positive? && failed.zero?
      end

      def to_h
        {
          total: total,
          passed: passed,
          failed: failed,
          score: score,
          examples: examples.map(&:to_h)
        }
      end

      private

      def numeric_scores
        examples.map { |example| score_value(example.score) }
      end

      def score_value(value)
        return 1 if value == true
        return 0 if value == false || value.nil?

        value
      end
    end

    def self.run(signature, examples:, metric:, predictor: RLM.method(:predict), **predict_options)
      new(signature, examples: examples, metric: metric, predictor: predictor, predict_options: predict_options).run
    end

    def initialize(signature, examples:, metric:, predictor:, predict_options: {})
      @signature = signature
      @examples = Array(examples)
      @metric = metric
      @predictor = predictor
      @predict_options = predict_options
    end

    def run
      Result.new(examples: examples.map { |example| evaluate(normalize_example(example)) })
    end

    private

    attr_reader :signature, :examples, :metric, :predictor, :predict_options

    def normalize_example(example)
      return example if example.is_a?(EvalExample)

      EvalExample.new(
        id: value_for(example, :id),
        input: value_for(example, :input),
        output: value_for(example, :output),
        expected_output: value_for(example, :expected_output),
        status: value_for(example, :status),
        metadata: value_for(example, :metadata) || {},
        trace: value_for(example, :trace)
      )
    end

    def evaluate(example)
      result = predictor.call(signature, input: example.input, **predict_options)
      score = metric.call(expected: example.expected_output, actual: result.output, result: result, example: example)
      ExampleResult.new(example: example, result: result, score: score)
    end

    def value_for(example, key)
      return example[key] if example.respond_to?(:key?) && example.key?(key)

      string_key = key.to_s
      example[string_key] if example.respond_to?(:key?) && example.key?(string_key)
    end
  end
end
