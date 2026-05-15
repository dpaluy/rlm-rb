# frozen_string_literal: true

module RuntimeFixtures
  TrackingSandbox = Class.new(RLM::Sandbox::UnsafeInProcess) do
    attr_reader :cleanup_called

    def initialize(exec_result: nil)
      super()
      @exec_result = exec_result
      @cleanup_called = false
    end

    def cleanup
      @cleanup_called = true
      super
    end

    def exec(code)
      return @exec_result if @exec_result

      super
    end
  end

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

  SymbolOutputSignature = Class.new do
    def self.name = "SymbolOutputSignature"
    def self.description = "Coerces string-keyed JSON into symbol-keyed output"
    def self.input_fields = { text: :string }
    def self.output_fields = { summary: :string }
    def self.validate_input(input) = input.key?(:text) || input.key?("text") ? [] : ["text is required"]
    def self.validate_output(output) = output.key?(:summary) ? [] : ["summary is required"]
    def self.coerce_output(output) = output.transform_keys(&:to_sym)
  end

  UsageLm = Class.new do
    attr_reader :cost_cents, :last_usage

    def initialize(responses:, usage:, cost_cents: 0)
      @responses = responses.dup
      @usage = usage
      @cost_cents_per_call = cost_cents
      @cost_cents = 0
      @last_usage = nil
    end

    def call(prompt:, **)
      raise RLM::ProviderError, "prompt must be a String" unless prompt.is_a?(String)

      @cost_cents += @cost_cents_per_call
      @last_usage = @usage
      @responses.shift
    end
  end

  FailingTool = Class.new(RLM::Tool) do
    def call
      raise RLM::ToolError, "tool boom"
    end
  end

  InvalidCoercingRootSignature = Class.new(RootSignature) do
    def self.coerce_output(_output)
      { "wrong" => "shape" }
    end
  end

  def tracking_sandbox(exec_result: nil)
    TrackingSandbox.new(exec_result: exec_result)
  end

  def root_code_response
    <<~RESPONSE
      <rlm-code>
        sub = predict("SubSignature", { "text" => "hello" })
        submit({ "summary" => sub.fetch("summary") })
      </rlm-code>
    RESPONSE
  end

  def tool_code_response
    <<~RESPONSE
      <rlm-code>
        tool("FailingTool", {})
      </rlm-code>
    RESPONSE
  end

  def submit_then_budget_code_response
    <<~RESPONSE
      <rlm-code>
        submit({ "summary" => "partial" })
        tool("MissingTool", {})
      </rlm-code>
    RESPONSE
  end
end
