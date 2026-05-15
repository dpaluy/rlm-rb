# frozen_string_literal: true

require_relative "../skill"
require_relative "../sandbox/context_limits"

module RLM
  module Skills
    class CSV < Skill
      registry_name "csv"
      description "Read CSV context files as JSON-serializable rows."
      helper "csv_rows(handle, headers: true)", description: "Return rows from a mounted CSV context file."

      def call(method_name, input, context:, limits: nil)
        case method_name.to_s
        when "rows" then rows(input, context: context, limits: limits)
        else raise ValidationError, "Unknown csv skill method: #{method_name}"
        end
      end

      private

      def rows(input, context:, limits:)
        file = context.file_for(fetch_string(input, "handle"))
        raise ValidationError, "Unknown file handle: #{input["handle"]}" if file.nil?

        content = file.read
        Sandbox::ContextLimits.new(context: context, limits: limits).validate_file_content!(file, content)
        parse_rows(content, headers: input.fetch("headers", true))
      end

      def parse_rows(content, headers:)
        rows = content.each_line.map { |line| parse_line(line.chomp) }.reject(&:empty?)
        return rows unless headers

        header = rows.shift || []
        rows.map { |row| header.each_with_index.to_h { |name, index| [name, row[index]] } }
      end

      def parse_line(line)
        fields = []
        field = +""
        quoted = false
        index = 0

        while index < line.length
          index = append_csv_char(line, index, field, quoted) do |new_quoted|
            quoted = new_quoted
          end
          if line[index] == "," && !quoted
            fields << field
            field = +""
          end
          index += 1
        end

        fields << field
      end

      def append_csv_char(line, index, field, quoted)
        char = line[index]
        if char == '"' && quoted && line[index + 1] == '"'
          field << char
          index + 1
        elsif char == '"'
          yield !quoted
          index
        else
          field << char unless char == "," && !quoted
          index
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
