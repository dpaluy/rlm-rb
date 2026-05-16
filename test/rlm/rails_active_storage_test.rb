# frozen_string_literal: true

require "test_helper"

class RLM::RailsActiveStorageTest < Minitest::Test
  def setup
    load File.expand_path("../../lib/rlm/rails.rb", __dir__) unless RLM.const_defined?(:Rails, false)
  end

  def test_file_wraps_blob
    file = RLM::Rails::ActiveStorage.file(blob("invoice.pdf", "PDF"))

    assert_equal "invoice.pdf", file.filename
    assert_equal "PDF", file.read
  end

  def test_file_wraps_attachment_blob
    attachment = Struct.new(:blob).new(blob("contract.txt", "terms"))

    file = RLM::Rails::ActiveStorage.file(attachment)

    assert_equal "contract.txt", file.filename
    assert_equal "terms", file.read
  end

  def test_file_rejects_unattached_attachment
    attachment = Struct.new(:attached?, :blob).new(false, blob("missing.txt", ""))

    assert_raises(ArgumentError) { RLM::Rails::ActiveStorage.file(attachment) }
  end

  def test_files_wraps_has_many_attachments
    attachments = [
      Struct.new(:blob).new(blob("a.txt", "A")),
      Struct.new(:blob).new(blob("b.txt", "B"))
    ]
    collection = Struct.new(:attachments).new(attachments)

    files = RLM::Rails::ActiveStorage.files(collection)

    assert_equal %w[a.txt b.txt], files.map(&:filename)
    assert_equal %w[A B], files.map(&:read)
  end

  def test_files_wraps_blob_collection
    collection = Struct.new(:blobs).new([blob("a.txt", "A"), blob("b.txt", "B")])

    assert_equal %w[a.txt b.txt], RLM::Rails::ActiveStorage.files(collection).map(&:filename)
  end

  private

  def blob(filename, payload)
    Struct.new(:filename, :content_type, :byte_size, :payload) do
      def download
        payload
      end
    end.new(filename, "text/plain", payload.bytesize, payload)
  end
end
