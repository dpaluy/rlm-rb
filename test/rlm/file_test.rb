# frozen_string_literal: true

require "test_helper"
require "stringio"
require "tempfile"

class RLM::FileTest < Minitest::Test
  def test_from_text_basic
    file = RLM::File.from_text("notes.txt", "hello")
    assert_equal "notes.txt", file.filename
    assert_equal "text/plain", file.content_type
    assert_equal 5, file.size_bytes
    assert_equal "hello", file.read
  end

  def test_from_text_detects_markdown
    file = RLM::File.from_text("policy.md", "# policy")
    assert_equal "text/markdown", file.content_type
  end

  def test_from_text_unknown_extension_uses_default
    file = RLM::File.from_text("strange.xyz", "data")
    assert_equal RLM::File::DEFAULT_CONTENT_TYPE, file.content_type
  end

  def test_from_text_requires_filename
    assert_raises(ArgumentError) { RLM::File.from_text("", "hi") }
  end

  def test_from_path_reads_disk
    Tempfile.create(["sample", ".md"]) do |tmp|
      tmp.write("# heading")
      tmp.flush
      file = RLM::File.from_path(tmp.path)
      assert_equal "text/markdown", file.content_type
      assert_equal "# heading", file.read
      assert_operator file.size_bytes, :>, 0
    end
  end

  def test_from_path_missing_raises
    assert_raises(ArgumentError) { RLM::File.from_path("/nonexistent/path") }
  end

  def test_from_io
    io = StringIO.new("col1,col2\n1,2\n")
    file = RLM::File.from_io(io, filename: "rows.csv")
    assert_equal "text/csv", file.content_type
    assert_equal "col1,col2\n1,2\n", file.read
  end

  def test_from_io_explicit_content_type_overrides_detection
    io = StringIO.new("payload")
    file = RLM::File.from_io(io, filename: "rows.csv", content_type: "application/octet-stream")
    assert_equal "application/octet-stream", file.content_type
  end

  def test_from_active_storage_requires_blob
    assert_raises(ArgumentError) { RLM::File.from_active_storage(nil) }
  end

  def test_from_active_storage_with_duck_type
    blob = Struct.new(:filename, :content_type, :byte_size, :payload) do
      def download
        payload
      end
    end.new("contract.pdf", "application/pdf", 128, "PDF-DATA")

    file = RLM::File.from_active_storage(blob)
    assert_equal "contract.pdf", file.filename
    assert_equal "application/pdf", file.content_type
    assert_equal 128, file.size_bytes
    assert_equal "PDF-DATA", file.read
  end

  def test_to_h_serializes_metadata
    file = RLM::File.from_text("notes.txt", "hello")
    assert_equal(
      { filename: "notes.txt", content_type: "text/plain", size_bytes: 5, source_kind: :text },
      file.to_h
    )
  end
end
