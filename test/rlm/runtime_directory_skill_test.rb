# frozen_string_literal: true

require "test_helper"

class RLM::RuntimeDirectorySkillTest < Minitest::Test
  Root = Class.new do
    def self.name = "RuntimeDirectorySkillRoot"
    def self.description = "Search context files"
    def self.input_fields = {}
    def self.output_fields = { match: :string }
    def self.validate_input(*) = []
    def self.validate_output(*) = []
  end

  def test_subprocess_generated_code_can_grep_files
    file = RLM::File.from_text("notes.txt", "alpha\nneedle here\n")
    response = '<rlm-code>submit({ match: grep_files("needle").first["text"] })</rlm-code>'
    lm = RLM::Lm::Mock.new(responses: [response])

    result = RLM.predict(
      Root,
      input: { notes: file },
      lm: lm,
      sandbox: RLM::Sandbox::Subprocess.new(timeout_seconds: 2),
      skills: [RLM::Skills::Directory.new]
    )

    assert result.success?
    assert_equal({ "match" => "needle here" }, result.output)
  end
end
