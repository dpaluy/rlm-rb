# frozen_string_literal: true

require "test_helper"

class RLM::Skills::PDFTest < Minitest::Test
  PDF_BODY = "%PDF-1.4\n1 0 obj\n/Type /Page\n(Invoice total 42)\n%%EOF"
  Extractor = Class.new do
    def extract_text(file:, content:)
      "#{file.filename}: #{content[/Invoice total \d+/]}"
    end
  end

  OCR = Class.new do
    def call(file, content:)
      { text: "OCR #{file.filename} #{content.bytesize}" }
    end
  end

  def test_info_returns_pdf_metadata_and_page_hint
    file = RLM::File.from_text("invoice.pdf", PDF_BODY)
    context = RLM::Context.new(files: [file])

    info = RLM::Skills::PDF.new.call("info", { "handle" => "file_1" }, context: context, limits: RLM::Limits.new)

    assert_equal "invoice.pdf", info["filename"]
    assert_equal "application/pdf", info["content_type"]
    assert_equal 1, info["page_count_hint"]
  end

  def test_text_preview_returns_printable_fragments
    file = RLM::File.from_text("invoice.pdf", PDF_BODY)
    context = RLM::Context.new(files: [file])

    preview = RLM::Skills::PDF.new.call(
      "text_preview",
      { "handle" => "file_1", "bytes" => 64 },
      context: context,
      limits: RLM::Limits.new
    )

    assert_includes preview["text"], "Invoice total 42"
  end

  def test_extract_text_uses_caller_supplied_extractor
    file = RLM::File.from_text("invoice.pdf", PDF_BODY)
    context = RLM::Context.new(files: [file])

    text = RLM::Skills::PDF.new(extractor: Extractor.new).call(
      "extract_text",
      { "handle" => "file_1" },
      context: context,
      limits: RLM::Limits.new
    )

    assert_equal({ "text" => "invoice.pdf: Invoice total 42" }, text)
  end

  def test_ocr_text_uses_caller_supplied_ocr_client
    file = RLM::File.from_text("scan.pdf", PDF_BODY)
    context = RLM::Context.new(files: [file])

    text = RLM::Skills::PDF.new(ocr: OCR.new).call("ocr_text", { "handle" => "file_1" }, context: context)

    assert_equal({ "text" => "OCR scan.pdf #{PDF_BODY.bytesize}" }, text)
  end

  def test_extract_text_requires_configured_client
    assert_raises(RLM::ValidationError) do
      RLM::Skills::PDF.new.call("extract_text", { "handle" => "file_1" }, context: context)
    end
  end

  def test_rejects_unknown_method
    assert_raises(RLM::ValidationError) do
      RLM::Skills::PDF.new.call("missing", { "handle" => "file_1" }, context: RLM::Context.new, limits: RLM::Limits.new)
    end
  end

  private

  def context
    RLM::Context.new(files: [RLM::File.from_text("invoice.pdf", PDF_BODY)])
  end
end
