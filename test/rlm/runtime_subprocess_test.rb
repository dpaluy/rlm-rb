# frozen_string_literal: true

require "test_helper"

class RLM::RuntimeSubprocessTest < Minitest::Test
  RootSignature = Class.new do
    def self.name = "RuntimeSubprocessRoot"
    def self.description = "Root runtime subprocess test"
    def self.input_fields = { text: :string }
    def self.output_fields = { summary: :string }
    def self.validate_input(input) = input.key?(:text) || input.key?("text") ? [] : ["text is required"]
    def self.validate_output(output) = output.key?(:summary) || output.key?("summary") ? [] : ["summary is required"]
  end

  SubSignature = Class.new do
    def self.name = "RuntimeSubprocessSub"
    def self.description = "Sub runtime subprocess test"
    def self.input_fields = { text: :string }
    def self.output_fields = { summary: :string }
    def self.validate_input(input) = input.key?(:text) || input.key?("text") ? [] : ["text is required"]
    def self.validate_output(output) = output.key?(:summary) || output.key?("summary") ? [] : ["summary is required"]
  end

  def test_predict_runs_generated_code_through_subprocess_sandbox
    root_response = <<~XML
      <rlm-code>
        log("subprocess runtime")
        sub = predict("RuntimeSubprocessSub", { text: "child input" })
        submit({ summary: sub["summary"] })
      </rlm-code>
    XML
    lm = RLM::Lm::Mock.new(responses: [root_response])
    sub_lm = RLM::Lm::Mock.new(responses: ['<rlm-final>{"summary":"isolated ok"}</rlm-final>'])

    result = RLM.predict(
      RootSignature,
      input: { text: "hello" },
      lm: lm,
      sub_lm: sub_lm,
      sandbox: RLM::Sandbox::Subprocess.new(timeout_seconds: 2),
      signatures: [SubSignature],
      limits: RLM::Limits.new(max_iterations: 2, max_llm_calls: 2)
    )

    assert result.success?
    assert_equal({ "summary" => "isolated ok" }, result.output)
    assert_includes result.trace.events.map { |event| event[:type] }, :runtime_logged
    assert_includes result.trace.events.map { |event| event[:type] }, :code_executed
  end
end
