# frozen_string_literal: true

require "test_helper"

class RLM::Skills::CSVTest < Minitest::Test
  def test_rows_returns_header_hashes_from_context_file
    file = RLM::File.from_text("totals.csv", "name,total\nAcme,10\n")
    context = RLM::Context.new(files: [file])

    rows = RLM::Skills::CSV.new.call("rows", { "handle" => "file_1" }, context: context, limits: RLM::Limits.new)

    assert_equal [{ "name" => "Acme", "total" => "10" }], rows
  end

  def test_rows_can_return_arrays_without_headers
    file = RLM::File.from_text("totals.csv", "Acme,10\n")
    context = RLM::Context.new(files: [file])

    rows = RLM::Skills::CSV.new.call(
      "rows",
      { "handle" => "file_1", "headers" => false },
      context: context,
      limits: RLM::Limits.new
    )

    assert_equal [%w[Acme 10]], rows
  end

  def test_rejects_unknown_method
    assert_raises(RLM::ValidationError) do
      RLM::Skills::CSV.new.call("missing", {}, context: RLM::Context.new, limits: RLM::Limits.new)
    end
  end
end
