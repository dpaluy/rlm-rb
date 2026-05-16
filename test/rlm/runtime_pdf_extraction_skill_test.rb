# frozen_string_literal: true

require "test_helper"

class RLM::RuntimePdfExtractionSkillTest < Minitest::Test
  Root = Class.new do
    def self.name = "RuntimePdfExtractionSkillRoot"
    def self.description = "Extract PDF text"
    def self.input_fields = {}
    def self.output_fields = { text: :string }
    def self.validate_input(*) = []
    def self.validate_output(*) = []
  end

  Extractor = Class.new do
    def call(_file, content:)
      content[/Invoice total \d+/]
    end
  end

  def test_subprocess_generated_code_can_call_pdf_extract_text
    file = RLM::File.from_text("invoice.pdf", "%PDF\n(Invoice total 42)\n%%EOF")
    lm = RLM::Lm::Mock.new(responses: ['<rlm-code>submit({ text: pdf_extract_text("file_1") })</rlm-code>'])

    result = RLM.predict(
      Root,
      input: { invoice: file },
      lm: lm,
      sandbox: RLM::Sandbox::Subprocess.new(timeout_seconds: 2),
      skills: [RLM::Skills::PDF.new(extractor: Extractor.new)]
    )

    assert result.success?
    assert_equal({ "text" => "Invoice total 42" }, result.output)
  end
end
