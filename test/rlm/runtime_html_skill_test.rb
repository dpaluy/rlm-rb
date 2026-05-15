# frozen_string_literal: true

require "test_helper"

class RLM::RuntimeHtmlSkillTest < Minitest::Test
  Root = Class.new do
    def self.name = "RuntimeHtmlSkillRoot"
    def self.description = "Inspect HTML"
    def self.input_fields = {}
    def self.output_fields = { link: :string }
    def self.validate_input(*) = []
    def self.validate_output(*) = []
  end

  def test_subprocess_generated_code_can_call_html_links
    file = RLM::File.from_text("page.html", '<a href="/next">Next</a>')
    lm = RLM::Lm::Mock.new(responses: ['<rlm-code>submit({ link: html_links("file_1").first["href"] })</rlm-code>'])

    result = RLM.predict(
      Root,
      input: { page: file },
      lm: lm,
      sandbox: RLM::Sandbox::Subprocess.new(timeout_seconds: 2),
      skills: [RLM::Skills::HTML.new]
    )

    assert result.success?
    assert_equal({ "link" => "/next" }, result.output)
  end
end
