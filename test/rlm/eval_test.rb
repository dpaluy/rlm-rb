# frozen_string_literal: true

require "test_helper"

class RLM::EvalTest < Minitest::Test
  FakeSignature = Class.new

  def test_run_evaluates_examples_with_metric
    outputs = [{ "answer" => "A" }, { "answer" => "B" }]
    predictor = predictor_for(outputs)
    metric = ->(expected:, actual:, **) { expected == actual }

    result = RLM::Eval.run(
      FakeSignature,
      examples: [
        { input: { "task" => "a" }, expected_output: { "answer" => "A" } },
        { input: { "task" => "b" }, expected_output: { "answer" => "nope" } }
      ],
      metric: metric,
      predictor: predictor
    )

    assert_equal 2, result.total
    assert_equal 1, result.passed
    assert_equal 1, result.failed
    assert_equal 0.5, result.score
    refute result.success?
  end

  def test_run_accepts_eval_examples_and_predict_options
    seen = []
    predictor = lambda do |signature, input:, **options|
      seen << [signature, input, options]
      runtime_result({ "answer" => "A" })
    end

    example = RLM::EvalExample.from_trace(
      trace_with_input({ "task" => "a" }),
      expected_output: { "answer" => "A" }
    )

    result = RLM::Eval.run(FakeSignature, examples: [example], metric: passing_metric, predictor: predictor, lm: :mock)

    assert result.success?
    assert_equal [FakeSignature, { "task" => "a" }, { lm: :mock }], seen.first
  end

  def test_result_serializes_summary_and_example_results
    result = RLM::Eval.run(
      FakeSignature,
      examples: [{ input: { "task" => "a" }, expected_output: { "answer" => "A" } }],
      metric: passing_metric,
      predictor: predictor_for([{ "answer" => "A" }])
    )

    payload = result.to_h

    assert_equal 1, payload[:total]
    assert_equal true, payload[:examples].first[:passed]
    assert_equal({ "answer" => "A" }, payload[:examples].first[:result][:output])
  end

  private

  def passing_metric
    ->(expected:, actual:, **) { expected == actual }
  end

  def predictor_for(outputs)
    lambda do |_signature, input:, **_options|
      raise "missing input" unless input

      runtime_result(outputs.shift)
    end
  end

  def runtime_result(output)
    RLM::Result.new(trace: trace_with_input({}), status: :completed, output: output)
  end

  def trace_with_input(input)
    RLM::Trace.new.tap { |trace| trace.record(:run_started, input: input) }
  end
end
