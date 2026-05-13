# frozen_string_literal: true

require "test_helper"

class RLM::RuntimeTest < Minitest::Test
  RootSignature = Class.new do
    def self.name = "RootSignature"
    def self.description = "Root runtime test"
    def self.input_fields = { text: :string }
    def self.output_fields = { summary: :string }
    def self.validate_input(input) = input.key?(:text) || input.key?("text") ? [] : ["text is required"]
    def self.validate_output(output) = output.key?(:summary) || output.key?("summary") ? [] : ["summary is required"]
  end

  SubSignature = Class.new do
    def self.name = "SubSignature"
    def self.description = "Sub runtime test"
    def self.input_fields = { text: :string }
    def self.output_fields = { summary: :string }
    def self.validate_input(input) = input.key?(:text) || input.key?("text") ? [] : ["text is required"]
    def self.validate_output(output) = output.key?(:summary) || output.key?("summary") ? [] : ["summary is required"]
  end

  def test_runs_code_response_through_sandbox_and_returns_submitted_output
    lm = RLM::Lm::Mock.new(responses: [root_code_response], cost_cents: 2)
    sub_lm = RLM::Lm::Mock.new(responses: ['<rlm-final>{"summary":"sub ok"}</rlm-final>'], cost_cents: 3)

    result = RLM.predict(
      RootSignature,
      input: { text: "hello" },
      lm: lm,
      sub_lm: sub_lm,
      sandbox: RLM::Sandbox::UnsafeInProcess.new,
      signatures: [SubSignature],
      limits: RLM::Limits.new(max_iterations: 2, max_llm_calls: 2)
    )

    assert result.success?
    assert_equal({ "summary" => "sub ok" }, result.output)
    assert_equal 2, result.llm_calls
    assert_equal 5, result.cost_cents
    assert_equal expected_code_run_events, event_types(result)
  end

  def test_direct_final_response_completes_without_sandbox_execution
    lm = RLM::Lm::Mock.new(responses: ['<rlm-final>{"summary":"done"}</rlm-final>'])
    sandbox = RLM::Sandbox::Mock.new

    result = RLM.predict(RootSignature, input: { text: "hello" }, lm: lm, sandbox: sandbox)

    assert result.success?
    assert_equal({ "summary" => "done" }, result.output)
    assert_empty sandbox.executed_code
  end

  def test_budget_exhaustion_returns_budget_result
    lm = RLM::Lm::Mock.new(responses: [root_code_response])
    sub_lm = RLM::Lm::Mock.new(responses: ['<rlm-final>{"summary":"sub ok"}</rlm-final>'])

    result = RLM.predict(
      RootSignature,
      input: { text: "hello" },
      lm: lm,
      sub_lm: sub_lm,
      sandbox: RLM::Sandbox::UnsafeInProcess.new,
      signatures: [SubSignature],
      limits: RLM::Limits.new(max_iterations: 2, max_llm_calls: 1)
    )

    assert_equal :budget_exceeded, result.status
    assert result.failed?
    assert_equal 1, result.llm_calls
  end

  def test_validation_failure_returns_failed_validation_result
    lm = RLM::Lm::Mock.new(responses: ['<rlm-final>{"wrong":"shape"}</rlm-final>'])

    result = RLM.predict(RootSignature, input: { text: "hello" }, lm: lm)

    assert_equal :failed_validation, result.status
    assert_equal ["summary is required"], result.validation_errors
  end

  private

  def event_types(result)
    result.trace.events.map { |event| event[:type] }
  end

  def expected_code_run_events
    %i[
      run_started
      validation_attempted
      root_prompt_created
      root_lm_called
      code_generated
      validation_attempted
      sub_lm_called
      validation_attempted
      output_submitted
      code_executed
      validation_attempted
      run_completed
    ]
  end

  def root_code_response
    <<~RESPONSE
      <rlm-code>
        sub = predict("SubSignature", { "text" => "hello" })
        submit({ "summary" => sub.fetch("summary") })
      </rlm-code>
    RESPONSE
  end
end
