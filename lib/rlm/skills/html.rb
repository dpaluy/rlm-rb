# frozen_string_literal: true

require_relative "../skill"
require_relative "../sandbox/context_limits"

module RLM
  module Skills
    class HTML < Skill
      registry_name "html"
      description "Inspect mounted HTML context files without browser automation."
      helper "html_text(handle)", description: "Return visible-ish text from an HTML context file."
      helper "html_links(handle)", description: "Return links from an HTML context file."

      def call(method_name, input, context:, limits: nil)
        file = context.file_for(fetch_string(input, "handle"))
        raise ValidationError, "Unknown file handle: #{input["handle"]}" if file.nil?

        content = bounded_content(file, context: context, limits: limits)
        case method_name.to_s
        when "text" then { "text" => html_text(content) }
        when "links" then html_links(content)
        else raise ValidationError, "Unknown html skill method: #{method_name}"
        end
      end

      private

      def bounded_content(file, context:, limits:)
        content = file.read
        Sandbox::ContextLimits.new(context: context, limits: limits).validate_file_content!(file, content)
        content
      end

      def html_text(content)
        content.gsub(%r{<script\b.*?</script>}im, " ")
               .gsub(%r{<style\b.*?</style>}im, " ")
               .gsub(/<[^>]+>/, " ")
               .then { |text| unescape_html(text) }
               .squeeze(" ")
               .strip
      end

      def html_links(content)
        content.scan(%r{<a\b[^>]*href=(["'])(.*?)\1[^>]*>(.*?)</a>}im).map do |_quote, href, label|
          { "href" => unescape_html(href), "text" => html_text(label) }
        end
      end

      def unescape_html(text)
        text.gsub("&amp;", "&")
            .gsub("&lt;", "<")
            .gsub("&gt;", ">")
            .gsub("&quot;", '"')
            .gsub("&#39;", "'")
      end

      def fetch_string(input, key)
        value = input[key] || input[key.to_sym]
        raise ValidationError, "#{key} must be a String" unless value.is_a?(String)

        value
      end
    end
  end
end
