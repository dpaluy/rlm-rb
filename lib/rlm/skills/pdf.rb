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
      helper "pdf_extract_text(handle)", description: "Return text from a caller-supplied PDF extraction client."
      helper "pdf_ocr_text(handle)", description: "Return OCR text from a caller-supplied PDF OCR client."

      def initialize(extractor: nil, ocr: nil)
        super()
        @extractor = extractor
        @ocr = ocr
      end

      def call(method_name, input, context:, limits: nil)
        file = context.file_for(fetch_string(input, "handle"))
        raise ValidationError, "Unknown file handle: #{input["handle"]}" if file.nil?

        case method_name.to_s
        when "info" then info(file)
        when "text_preview" then text_preview(file, input, context: context, limits: limits)
        when "extract_text" then client_text(extractor, :extract_text, file, context: context, limits: limits)
        when "ocr_text" then client_text(ocr, :ocr_text, file, context: context, limits: limits)
        else raise ValidationError, "Unknown pdf skill method: #{method_name}"
        end
      end

      private

      attr_reader :extractor, :ocr

      def info(file)
        content = file.read
        { "filename" => file.filename, "content_type" => file.content_type, "size_bytes" => file.size_bytes,
          "page_count_hint" => content.scan(%r{/Type\s*/Page\b}).length }
      end

      def text_preview(file, input, context:, limits:)
        content = bounded_content(file, context: context, limits: limits)
        { "text" => printable_preview(content, bytes: input.fetch("bytes", 4096)) }
      end

      def client_text(client, method_name, file, context:, limits:)
        raise ValidationError, "pdf #{method_name} client is not configured" if client.nil?

        result = dispatch_client(client, method_name, file, bounded_content(file, context: context, limits: limits))
        text = result.is_a?(Hash) ? fetch_value(result, "text") : result
        raise ValidationError, "pdf #{method_name} result must be a String or include text" unless text.is_a?(String)

        { "text" => text }
      end

      def bounded_content(file, context:, limits:)
        content = file.read
        Sandbox::ContextLimits.new(context: context, limits: limits).validate_file_content!(file, content)
        content
      end

      def dispatch_client(client, method_name, file, content)
        return client.call(file, content: content) if client.respond_to?(:call)
        return client.public_send(method_name, file: file, content: content) if client.respond_to?(method_name)

        raise ValidationError, "pdf client must respond to #call or ##{method_name}"
      end

      def printable_preview(content, bytes:)
        content.byteslice(0, bytes.to_i).to_s.gsub(/[^\p{Print}\n\t]/, " ").squeeze(" ").strip
      end

      def fetch_string(input, key)
        value = input[key] || input[key.to_sym]
        raise ValidationError, "#{key} must be a String" unless value.is_a?(String)

        value
      end

      def fetch_value(hash, key)
        hash[key] || hash[key.to_sym]
      end
    end
  end
end
