# frozen_string_literal: true

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
        extras.each { |name, extra| registry[name] = extra }
      end

      def register(candidate)
        Signature.validate_interface!(candidate)
        registry[Signature.name_for(candidate)] = candidate
        registry[candidate] = candidate
      end
    end
  end
end
