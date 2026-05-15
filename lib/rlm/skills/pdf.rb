# frozen_string_literal: true

require_relative "../skill"
require_relative "../sandbox/context_limits"

module RLM
  module Skills
    class PDF < Skill
      registry_name "pdf"
      description "Inspect mounted PDF context files without external parsing dependencies."
      helper "pdf_info(handle)", description: "Return PDF filename, content type, size, and page-count hint."
      helper "pdf_text_preview(handle, bytes: 4096)", description: "Return printable text fragments from a PDF file."

      def call(method_name, input, context:, limits: nil)
        file = context.file_for(fetch_string(input, "handle"))
        raise ValidationError, "Unknown file handle: #{input["handle"]}" if file.nil?

        case method_name.to_s
        when "info" then info(file)
        when "text_preview" then text_preview(file, input, context: context, limits: limits)
        else raise ValidationError, "Unknown pdf skill method: #{method_name}"
        end
      end

      private

      def info(file)
        content = file.read
        { "filename" => file.filename, "content_type" => file.content_type, "size_bytes" => file.size_bytes,
          "page_count_hint" => content.scan(%r{/Type\s*/Page\b}).length }
      end

      def text_preview(file, input, context:, limits:)
        content = file.read
        Sandbox::ContextLimits.new(context: context, limits: limits).validate_file_content!(file, content)
        { "text" => printable_preview(content, bytes: input.fetch("bytes", 4096)) }
      end

      def printable_preview(content, bytes:)
        content.byteslice(0, bytes.to_i).to_s.gsub(/[^\p{Print}\n\t]/, " ").squeeze(" ").strip
      end

      def fetch_string(input, key)
        value = input[key] || input[key.to_sym]
        raise ValidationError, "#{key} must be a String" unless value.is_a?(String)

        value
      end
    end
  end
end
