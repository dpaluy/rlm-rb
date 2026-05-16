# frozen_string_literal: true

require "test_helper"

class RLM::RuntimeBrowserSkillTest < Minitest::Test
  Root = Class.new do
    def self.name = "RuntimeBrowserSkillRoot"
    def self.description = "Inspect browser-rendered page"
    def self.input_fields = {}
    def self.output_fields = { title: :string }
    def self.validate_input(*) = []
    def self.validate_output(*) = []
  end

  BrowserClient = Class.new do
    def call(action, input)
      return { "title" => "Rendered", "url" => input.fetch("url") } if action == "snapshot"

      raise "unexpected action"
    end
  end

  def test_subprocess_generated_code_can_call_browser_snapshot
    lm = RLM::Lm::Mock.new(
      responses: ['<rlm-code>submit({ title: browser_snapshot("https://example.test")["title"] })</rlm-code>']
    )

    result = RLM.predict(
      Root,
      input: {},
      lm: lm,
      sandbox: RLM::Sandbox::Subprocess.new(timeout_seconds: 2),
      skills: [RLM::Skills::Browser.new(client: BrowserClient.new)]
    )

    assert result.success?
    assert_equal({ "title" => "Rendered" }, result.output)
  end
end
