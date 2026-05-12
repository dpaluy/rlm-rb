# frozen_string_literal: true

require "test_helper"

class RLM::ContextTest < Minitest::Test
  def test_manifest_assigns_stable_handles
    a = RLM::File.from_text("a.txt", "alpha")
    b = RLM::File.from_text("b.md", "# beta")
    context = RLM::Context.new(inputs: { vendor_id: 7 }, files: [a, b])

    manifest = context.manifest
    handles = manifest[:files].map { |f| f[:handle] }
    assert_equal %w[file_1 file_2], handles

    assert_equal "a.txt", manifest[:files].first[:filename]
    assert_equal "/mnt/rlm/files/a.txt", manifest[:files].first[:sandbox_path]
    assert_equal({ vendor_id: 7 }, manifest[:inputs])
  end

  def test_file_for_round_trip
    file = RLM::File.from_text("c.txt", "cee")
    context = RLM::Context.new(files: [file])
    assert_same file, context.file_for("file_1")
    assert_equal "file_1", context.handle_for(file)
  end

  def test_input_file_values_become_handle_references
    file = RLM::File.from_text("invoice.pdf", "binary")
    context = RLM::Context.new(inputs: { invoice_pdf: file, vendor_id: 4 }, files: [file])

    assert_equal({ file_handle: "file_1" }, context.manifest[:inputs][:invoice_pdf])
    assert_equal 4, context.manifest[:inputs][:vendor_id]
  end
end
