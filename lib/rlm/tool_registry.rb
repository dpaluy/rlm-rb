# frozen_string_literal: true

require_relative "tool"

module RLM
  class ToolRegistry
    include Enumerable

    def initialize(tools = [])
      @tools = {}
      Array(tools).each { |tool| register(tool) }
    end

    def register(tool)
      klass = tool_class(tool)
      validate_tool!(klass)
      name = klass.registry_name
      raise ArgumentError, "duplicate tool: #{name}" if tools.key?(name)

      tools[name] = tool
      self
    end

    def fetch(name)
      key = name.to_s
      tools[key] || tools.values.find { |tool| tool_class(tool).name == key }
    end

    def each(&)
      tools.values.each(&)
    end

    def to_a
      tools.values
    end

    def manifest
      tools.values.map do |tool|
        klass = tool_class(tool)
        {
          name: klass.registry_name,
          description: klass.description,
          category: klass.category
        }
      end
    end

    private

    attr_reader :tools

    def validate_tool!(klass)
      raise ArgumentError, "tool must inherit from RLM::Tool" unless klass <= RLM::Tool
      raise ArgumentError, "tool must be read-only: #{klass.registry_name}" unless klass.category == :read_only
    end

    def tool_class(tool)
      tool.is_a?(Class) ? tool : tool.class
    end
  end
end
