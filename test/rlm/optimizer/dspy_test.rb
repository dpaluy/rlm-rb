# frozen_string_literal: true

require "test_helper"
require "dspy"

class RLM::Optimizer::DspyTest < Minitest::Test
  InvoiceSummary = Class.new(DSPy::Signature) do
    description "Summarize invoice text"

    input do
      const :text, String
    end

    output do
      const :summary, String
    end
  end

  Result = Struct.new(:output, keyword_init: true)

  class FakeTeleprompter
    attr_reader :program, :trainset, :valset

    def compile(program, trainset:, valset: nil)
      @program = program
      @trainset = trainset
      @valset = valset
      :compiled
    end
  end

  def test_compile_converts_rlm_eval_examples_to_dspy_examples
    teleprompter = FakeTeleprompter.new
    example = RLM::EvalExample.new(input: { "text" => "paid invoice" }, output: { "summary" => "paid" }, trace: nil)

    result = RLM::Optimizer::Dspy.compile(
      RLM::Signature::Dspy.new(InvoiceSummary),
      examples: [example],
      valset: [{ input: { text: "open invoice" }, expected_output: { summary: "open" } }],
      teleprompter: teleprompter,
      lm: :mock
    )

    assert_equal :compiled, result
    assert_kind_of RLM::Optimizer::DspyProgram, teleprompter.program
    assert_equal({ lm: :mock }, teleprompter.program.predict_options)
    assert_dspy_example teleprompter.trainset.first, input: { text: "paid invoice" }, expected: { summary: "paid" }
    assert_dspy_example teleprompter.valset.first, input: { text: "open invoice" }, expected: { summary: "open" }
  end

  def test_program_calls_rlm_predictor_with_keyword_input
    calls = []
    predictor = lambda do |signature, input:, **options|
      calls << [signature, input, options]
      Result.new(output: { summary: input.fetch(:text).upcase })
    end
    signature = RLM::Signature::Dspy.new(InvoiceSummary)
    program = RLM::Optimizer::DspyProgram.new(signature, predictor: predictor, predict_options: { lm: :mock })

    assert_equal({ summary: "HELLO" }, program.call(text: "hello"))
    assert_equal [[signature, { text: "hello" }, { lm: :mock }]], calls
    assert_equal InvoiceSummary, program.signature_class
  end

  def test_compile_requires_expected_output
    error = assert_raises(ArgumentError) do
      RLM::Optimizer::Dspy.compile(
        RLM::Signature::Dspy.new(InvoiceSummary),
        examples: [{ input: { text: "missing expected" } }],
        teleprompter: FakeTeleprompter.new
      )
    end

    assert_includes error.message, "expected output"
  end

  private

  def assert_dspy_example(example, input:, expected:)
    assert_kind_of DSPy::Example, example
    assert_equal input, example.input_values
    assert_equal expected, example.expected_values
  end
end
