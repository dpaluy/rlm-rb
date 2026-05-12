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

  def test_sibling_subclasses_have_independent_metadata
    a = Class.new(RLM::Tool) { description "A" }
    b = Class.new(RLM::Tool) { description "B" }
    assert_equal "A", a.description
    assert_equal "B", b.description
  end
end
