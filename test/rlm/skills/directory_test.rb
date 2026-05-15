# frozen_string_literal: true

require "test_helper"

class RLM::Skills::DirectoryTest < Minitest::Test
  def test_files_returns_context_manifest_files
    file = RLM::File.from_text("notes.txt", "hello")
    context = RLM::Context.new(files: [file])

    files = RLM::Skills::Directory.new.call("files", {}, context: context, limits: RLM::Limits.new)

    assert_equal "file_1", files.first[:handle]
    assert_equal "notes.txt", files.first[:filename]
  end

  def test_grep_returns_matching_lines
    file = RLM::File.from_text("notes.txt", "alpha\nneedle here\n")
    context = RLM::Context.new(files: [file])

    matches = RLM::Skills::Directory.new.call(
      "grep",
      { "query" => "needle" },
      context: context,
      limits: RLM::Limits.new
    )

    assert_equal [{ "handle" => "file_1", "filename" => "notes.txt", "line" => 2, "text" => "needle here" }], matches
  end

  def test_rejects_unknown_method
    assert_raises(RLM::ValidationError) do
      RLM::Skills::Directory.new.call("missing", {}, context: RLM::Context.new, limits: RLM::Limits.new)
    end
  end
end
