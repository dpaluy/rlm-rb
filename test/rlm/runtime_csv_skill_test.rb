# frozen_string_literal: true

require "test_helper"

class RLM::RuntimeCsvSkillTest < Minitest::Test
  Root = Class.new do
    def self.name = "RuntimeCsvSkillRoot"
    def self.description = "Read CSV totals"
    def self.input_fields = {}
    def self.output_fields = { first_total: :string }
    def self.validate_input(*) = []
    def self.validate_output(*) = []
  end

  def test_subprocess_generated_code_can_call_csv_rows
    file = RLM::File.from_text("totals.csv", "name,total\nAcme,10\n")
    response = '<rlm-code>submit({ first_total: csv_rows("file_1").first["total"] })</rlm-code>'
    lm = RLM::Lm::Mock.new(responses: [response])

    result = RLM.predict(
      Root,
      input: { totals: file },
      lm: lm,
      sandbox: RLM::Sandbox::Subprocess.new(timeout_seconds: 2),
      skills: [RLM::Skills::CSV.new]
    )

    assert result.success?
    assert_equal({ "first_total" => "10" }, result.output)
  end
end
