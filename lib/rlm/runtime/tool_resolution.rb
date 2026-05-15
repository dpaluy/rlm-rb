# frozen_string_literal: true

module RLM
  class Runtime
    class Bridge
      module ToolResolution
        private

        def find_tool(tool_name)
          return tools.fetch(tool_name) if tools.is_a?(ToolRegistry)

          name = tool_name.to_s
          tools.find do |tool|
            tool_names = [tool_class(tool).registry_name, tool_class(tool).name]
            tool_names.include?(name)
          end
        end

        def tool_class(tool)
          tool.is_a?(Class) ? tool : tool.class
        end

        def tool_instance(tool)
          tool.is_a?(Class) ? tool.new : tool
        end

        def validate_tool_input!(tool, input)
          errors = tool_class(tool).validate_input(input)
          raise ToolError, errors.join(", ") unless errors.empty?
        end

        def validate_tool_output!(tool, output)
          errors = tool_class(tool).validate_output(output)
          raise ToolError, errors.join(", ") unless errors.empty?
        end
      end
    end
  end
end
