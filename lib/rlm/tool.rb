# frozen_string_literal: true

module RLM
  class Tool
    CATEGORIES = %i[read_only write_requires_approval write_allowed dangerous_disabled].freeze

    class << self
      def description(text = nil)
        return @description if text.nil?

        @description = text
      end

      def category(value = nil)
        return @category || :read_only if value.nil?
        raise ArgumentError, "Unknown category: #{value.inspect}" unless CATEGORIES.include?(value)

        @category = value
      end

      def registry_name
        @registry_name ||= name.to_s.split("::").last
      end

      def inherited(subclass)
        super
        subclass.instance_variable_set(:@description, nil)
        subclass.instance_variable_set(:@category, nil)
      end
    end

    def call(**kwargs)
      raise NotImplementedError, "#{self.class} must implement #call"
    end
  end
end
