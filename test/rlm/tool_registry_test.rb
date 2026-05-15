# frozen_string_literal: true

require "test_helper"

class RLM::ToolRegistryTest < Minitest::Test
  LookupVendor = Class.new(RLM::Tool) do
    description "Look up vendor metadata."
    input_schema vendor_id: :integer
    output_schema vendor_id: :integer, name: :string

    def call(vendor_id:)
      { vendor_id: vendor_id, name: "ACME" }
    end
  end

  WriteVendor = Class.new(RLM::Tool) do
    category :write_requires_approval
  end

  def test_registers_and_fetches_read_only_tools
    registry = RLM::ToolRegistry.new([LookupVendor])

    assert_same LookupVendor, registry.fetch("LookupVendor")
    assert_equal [LookupVendor], registry.to_a
  end

  def test_registers_write_tools_for_policy_enforcement_at_call_time
    registry = RLM::ToolRegistry.new([WriteVendor])

    assert_same WriteVendor, registry.fetch("WriteVendor")
    assert_equal :write_requires_approval, registry.manifest.first[:category]
  end

  def test_manifest_exposes_safe_metadata
    manifest = RLM::ToolRegistry.new([LookupVendor]).manifest

    assert_equal "LookupVendor", manifest.first[:name]
    assert_equal "Look up vendor metadata.", manifest.first[:description]
    assert_equal :read_only, manifest.first[:category]
    assert_equal({ vendor_id: :integer }, manifest.first[:input_schema])
    assert_equal({ vendor_id: :integer, name: :string }, manifest.first[:output_schema])
  end

  def test_rejects_duplicate_registry_names
    registry = RLM::ToolRegistry.new([LookupVendor])

    error = assert_raises(ArgumentError) { registry.register(LookupVendor.new) }

    assert_includes error.message, "duplicate tool"
  end
end
