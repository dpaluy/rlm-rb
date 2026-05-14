# frozen_string_literal: true

require_relative "../errors"
require_relative "../signature"

module RLM
  class Runtime
    class SignatureRegistry
      def self.build(root_signature, extras)
        new(root_signature, extras).build
      end

      def initialize(root_signature, extras)
        @root_signature = root_signature
        @extras = extras
        @registry = {}
      end

      def build
        register(root_signature)
        register_extras
        registry
      end

      private

      attr_reader :root_signature, :extras, :registry

      def register_extras
        case extras
        when Hash then register_hash_extras
        else Array(extras).each { |extra| register(extra) }
        end
      end

      def register_hash_extras
        extras.each_value { |extra| register(extra) }
        extras.each { |name, extra| register_alias(name, extra) }
      end

      def register_alias(name, candidate)
        validate_alias_name!(name)
        if normalized_name_registered?(name)
          raise ConfigurationError, "Signature alias already registered: #{name.inspect}"
        end

        registry[name] = candidate
      end

      def validate_alias_name!(name)
        unless name.is_a?(String) || name.is_a?(Symbol)
          raise ConfigurationError, "Signature alias must be a String or Symbol: #{name.inspect}"
        end
        raise ConfigurationError, "Signature alias cannot be empty" if name.to_s.empty?
      end

      def normalized_name_registered?(name)
        normalized = name.to_s
        registry.keys.any? do |key|
          (key.is_a?(String) || key.is_a?(Symbol)) && key.to_s == normalized
        end
      end

      def register(candidate)
        Signature.validate_interface!(candidate)
        name = Signature.name_for(candidate)
        raise ConfigurationError, "Signature already registered: #{name.inspect}" if normalized_name_registered?(name)
        raise ConfigurationError, "Signature class already registered: #{candidate.inspect}" if registry.key?(candidate)

        registry[name] = candidate
        registry[candidate] = candidate
      end
    end
  end
end
