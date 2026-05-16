# frozen_string_literal: true

require "test_helper"
require "dspy"

class RLM::Optimizer::DspyPresetsTest < Minitest::Test
  InvoiceSummary = Class.new(DSPy::Signature) do
    description "Summarize invoice text"

    input do
      const :text, String
    end

    output do
      const :summary, String
    end
  end

  class FakeTeleprompter
    attr_reader :metric, :options, :trainset

    def initialize(metric:, **options)
      @metric = metric
      @options = options
    end

    def compile(_program, trainset:, valset: nil)
      @trainset = trainset
      { trainset: trainset, valset: valset, options: options }
    end
  end

  def teardown
    RLM::Optimizer::DspyPresets.unregister(:fake_test)
  end

  def test_available_includes_builtin_mipro_v2_presets
    assert_includes RLM::Optimizer::DspyPresets.available, "mipro_v2_light"
    assert_includes RLM::Optimizer::DspyPresets.available, "mipro_v2_medium"
    assert_includes RLM::Optimizer::DspyPresets.available, "mipro_v2_heavy"
  end

  def test_registered_preset_can_drive_compile
    metric = ->(*) { true }
    RLM::Optimizer::DspyPresets.register(:fake_test) do |metric:, **options|
      FakeTeleprompter.new(metric: metric, **options)
    end

    result = RLM::Optimizer::Dspy.compile(
      RLM::Signature::Dspy.new(InvoiceSummary),
      examples: [{ input: { text: "paid invoice" }, expected_output: { summary: "paid" } }],
      preset: :fake_test,
      metric: metric,
      optimizer_options: { budget: 2 },
      lm: :mock
    )

    assert_equal({ budget: 2 }, result.fetch(:options))
    assert_kind_of DSPy::Example, result.fetch(:trainset).first
  end

  def test_unknown_preset_is_rejected
    error = assert_raises(ArgumentError) do
      RLM::Optimizer::DspyPresets.build(:missing)
    end

    assert_includes error.message, "Unknown dspy optimizer preset"
  end

  def test_builtin_mipro_v2_preset_uses_optional_dspy_support_when_available
    if defined?(DSPy::Teleprompt::MIPROv2)
      teleprompter = RLM::Optimizer::DspyPresets.build(:mipro_v2_light)
      assert_kind_of DSPy::Teleprompt::MIPROv2, teleprompter
      assert_equal DSPy::Teleprompt::AutoPreset::Light, teleprompter.config.auto_preset
    else
      assert_raises(LoadError) { RLM::Optimizer::DspyPresets.build(:mipro_v2_light) }
    end
  end
end
