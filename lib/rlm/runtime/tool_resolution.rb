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

        def authorize_tool!(tool, input)
          ensure_tool_category_allowed!(tool)
          return unless tool_authorizer.respond_to?(:call)

          allowed = tool_authorizer.call(tool: tool_class(tool), input: input, context: context)
          raise ToolError, "Tool is not authorized: #{tool_class(tool).registry_name}" unless allowed
        end

        def ensure_tool_category_allowed!(tool)
          case tool_class(tool).category
          when :read_only, :write_allowed
            nil
          when :write_requires_approval
            unless tool_authorizer.respond_to?(:call)
              raise ToolError, "Tool requires approval: #{tool_class(tool).registry_name}"
            end
          when :dangerous_disabled
            raise ToolError, "Tool is disabled: #{tool_class(tool).registry_name}"
          else
            raise ToolError, "Unknown tool category: #{tool_class(tool).category.inspect}"
          end
        end

        def cacheable_tool?(tool)
          tool_class(tool).category == :read_only
        end

        def validate_tool_input!(tool, input)
          errors = tool_class(tool).validate_input(input)
          raise ToolError, errors.join(", ") unless errors.empty?
        end

        def validate_tool_output!(tool, output)
          errors = tool_class(tool).validate_output(output)
          raise ToolError, errors.join(", ") unless errors.empty?
        end

        def record_tool_call!(tool, input)
          trace.record(
            :tool_called,
            tool: tool_class(tool).registry_name,
            category: tool_class(tool).category,
            input: input
          )
        end
      end
    end
  end
end
