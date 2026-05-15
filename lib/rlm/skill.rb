# frozen_string_literal: true

require_relative "errors"

module RLM
  class Skill
    class << self
      def registry_name(value = nil)
        @registry_name = value.to_s unless value.nil?
        @registry_name || default_registry_name
      end

      def description(value = nil)
        @description = value unless value.nil?
        @description
      end

      def helper(name, description:)
        helpers << { name: name.to_s, description: description }
      end

      def helpers
        @helpers ||= []
      end

      def manifest
        {
          name: registry_name,
          description: description,
          helpers: helpers
        }.compact
      end

      private

      def default_registry_name
        name.split("::").last.downcase
      end
    end

    def registry_name
      self.class.registry_name
    end

    def manifest
      self.class.manifest
    end

    def call(method_name, input, context:, limits: nil)
      raise NotImplementedError, "#{self.class} must implement ##{method_name}"
    end
  end
end
