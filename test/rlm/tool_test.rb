# frozen_string_literal: true

require "test_helper"

class RLM::ToolTest < Minitest::Test
  def test_subclass_description_dsl
    klass = Class.new(RLM::Tool) do
      description "Looks up a vendor."
    end
    assert_equal "Looks up a vendor.", klass.description
  end

  def test_category_defaults_to_read_only
    klass = Class.new(RLM::Tool)
    assert_equal :read_only, klass.category
  end

  def test_category_accepts_known_values
    klass = Class.new(RLM::Tool) do
      category :write_requires_approval
    end
    assert_equal :write_requires_approval, klass.category
  end

  def test_unknown_category_raises
    assert_raises(ArgumentError) { Class.new(RLM::Tool) { category :destroy_everything } }
  end

  def test_call_must_be_implemented
    klass = Class.new(RLM::Tool)
    assert_raises(NotImplementedError) { klass.new.call(arg: 1) }
  end

  def test_input_and_output_schema_dsl
    klass = Class.new(RLM::Tool) do
      input_schema vendor_id: :integer
      output_schema name: :string, active: :boolean
    end

    assert_equal({ vendor_id: :integer }, klass.input_schema)
    assert_equal({ name: :string, active: :boolean }, klass.output_schema)
  end

  def test_schema_validation_reports_missing_and_invalid_fields
    klass = Class.new(RLM::Tool) do
      input_schema vendor_id: :integer, name: :string
    end

    errors = klass.validate_input("vendor_id" => "x")

    assert_includes errors, "input.vendor_id must be integer"
    assert_includes errors, "input.name is required"
  end

  def test_unknown_schema_type_raises
    assert_raises(ArgumentError) { Class.new(RLM::Tool) { input_schema vendor_id: :uuid } }
  end

  def test_sibling_subclasses_have_independent_metadata
    a = Class.new(RLM::Tool) do
      description "A"
      input_schema a: :string
    end
    b = Class.new(RLM::Tool) do
      description "B"
      input_schema b: :string
    end
    assert_equal "A", a.description
    assert_equal "B", b.description
    assert_equal({ a: :string }, a.input_schema)
    assert_equal({ b: :string }, b.input_schema)
  end
end
