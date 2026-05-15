# frozen_string_literal: true

require "test_helper"

class RLM::RuntimePdfSkillTest < Minitest::Test
  Root = Class.new do
    def self.name = "RuntimePdfSkillRoot"
    def self.description = "Inspect a PDF"
    def self.input_fields = {}
    def self.output_fields = { pages: :integer }
    def self.validate_input(*) = []
    def self.validate_output(*) = []
  end

  def test_subprocess_generated_code_can_call_pdf_info
    file = RLM::File.from_text("invoice.pdf", "%PDF-1.4\n/Type /Page\n%%EOF")
    lm = RLM::Lm::Mock.new(responses: ['<rlm-code>submit({ pages: pdf_info("file_1")["page_count_hint"] })</rlm-code>'])

    result = RLM.predict(
      Root,
      input: { invoice: file },
      lm: lm,
      sandbox: RLM::Sandbox::Subprocess.new(timeout_seconds: 2),
      skills: [RLM::Skills::PDF.new]
    )

    assert result.success?
    assert_equal({ "pages" => 1 }, result.output)
  end
end
