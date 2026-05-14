# frozen_string_literal: true

require "test_helper"

class RLM::Runtime::SignatureRegistryTest < Minitest::Test
  RootSignature = Class.new do
    def self.name = "RootSignature"
    def self.description = "Root registry test"
    def self.input_fields = {}
    def self.output_fields = {}
    def self.validate_input(_input) = []
    def self.validate_output(_output) = []
  end

  ExtraSignature = Class.new do
    def self.name = "ExtraSignature"
    def self.description = "Extra registry test"
    def self.input_fields = {}
    def self.output_fields = {}
    def self.validate_input(_input) = []
    def self.validate_output(_output) = []
  end

  def test_registers_root_signature_by_name_and_class
    registry = RLM::Runtime::SignatureRegistry.build(RootSignature, [])

    assert_same RootSignature, registry["RootSignature"]
    assert_same RootSignature, registry[RootSignature]
  end

  def test_registers_extra_signatures_from_array
    registry = RLM::Runtime::SignatureRegistry.build(RootSignature, [ExtraSignature])

    assert_same ExtraSignature, registry["ExtraSignature"]
    assert_same ExtraSignature, registry[ExtraSignature]
  end

  def test_registers_hash_aliases_for_extra_signatures
    registry = RLM::Runtime::SignatureRegistry.build(RootSignature, custom: ExtraSignature)

    assert_same ExtraSignature, registry[:custom]
    assert_same ExtraSignature, registry["ExtraSignature"]
  end

  def test_rejects_invalid_signature_interface
    assert_raises(RLM::ConfigurationError) do
      RLM::Runtime::SignatureRegistry.build(RootSignature, [Object.new])
    end
  end

  def test_rejects_invalid_hash_alias
    assert_raises(RLM::ConfigurationError) do
      RLM::Runtime::SignatureRegistry.build(RootSignature, "" => ExtraSignature)
    end
  end

  def test_rejects_alias_collision_with_root_signature_name
    assert_raises(RLM::ConfigurationError) do
      RLM::Runtime::SignatureRegistry.build(RootSignature, "RootSignature" => ExtraSignature)
    end
  end

  def test_rejects_symbol_alias_collision_with_root_signature_name
    assert_raises(RLM::ConfigurationError) do
      RLM::Runtime::SignatureRegistry.build(RootSignature, RootSignature: ExtraSignature)
    end
  end

  def test_rejects_string_symbol_alias_collision_for_same_name
    assert_raises(RLM::ConfigurationError) do
      RLM::Runtime::SignatureRegistry.build(RootSignature, "custom" => ExtraSignature, custom: ExtraSignature)
    end
  end

  def test_rejects_alias_collision_with_existing_extra_signature_name
    assert_raises(RLM::ConfigurationError) do
      RLM::Runtime::SignatureRegistry.build(RootSignature, ExtraSignature: ExtraSignature)
    end
  end

  def test_rejects_alias_collision_with_signature_class_key
    assert_raises(RLM::ConfigurationError) do
      RLM::Runtime::SignatureRegistry.build(RootSignature, RootSignature => ExtraSignature)
    end
  end

  def test_rejects_duplicate_signature_names
    assert_raises(RLM::ConfigurationError) do
      RLM::Runtime::SignatureRegistry.build(RootSignature, [RootSignature])
    end
  end
end
