# frozen_string_literal: true

require_relative "../skill"
require_relative "../sandbox/context_limits"

module RLM
  module Skills
    class Directory < Skill
      registry_name "directory"
      description "Inspect and search mounted context files."
      helper "directory_files", description: "Return mounted file metadata from the current context."
      helper "grep_files(query)", description: "Return matching lines from mounted context files."

      def call(method_name, input, context:, limits: nil)
        case method_name.to_s
        when "files" then context.manifest[:files]
        when "grep" then grep(input, context: context, limits: limits)
        else raise ValidationError, "Unknown directory skill method: #{method_name}"
        end
      end

      private

      def grep(input, context:, limits:)
        query = fetch_string(input, "query")
        context.manifest[:files].flat_map do |entry|
          grep_file(context.file_for(entry[:handle]), entry, query, context: context, limits: limits)
        end
      end

      def grep_file(file, entry, query, context:, limits:)
        content = file.read
        Sandbox::ContextLimits.new(context: context, limits: limits).validate_file_content!(file, content)
        content.each_line.with_index(1).filter_map do |line, line_number|
          next unless line.include?(query)

          { "handle" => entry[:handle], "filename" => file.filename, "line" => line_number, "text" => line.chomp }
        end
      end

      def fetch_string(input, key)
        value = input[key] || input[key.to_sym]
        raise ValidationError, "#{key} must be a String" unless value.is_a?(String)

        value
      end
    end
  end
end
