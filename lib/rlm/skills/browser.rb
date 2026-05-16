# frozen_string_literal: true

require_relative "../skill"

module RLM
  module Skills
    class Browser < Skill
      registry_name "browser"
      description "Inspect browser-rendered pages through a caller-supplied client."
      helper "browser_text(url)", description: "Return rendered text for a URL through the configured browser client."
      helper "browser_links(url)", description: "Return rendered links for a URL through the configured browser client."
      helper(
        "browser_snapshot(url)",
        description: "Return a JSON snapshot for a URL through the configured browser client."
      )

      def initialize(client:)
        super()
        @client = client
      end

      def call(method_name, input, context:, limits: nil) # rubocop:disable Lint/UnusedMethodArgument
        url = fetch_url(input)

        case method_name.to_s
        when "text" then text_result(dispatch("text", "url" => url))
        when "links" then links_result(dispatch("links", "url" => url))
        when "snapshot" then snapshot_result(dispatch("snapshot", "url" => url))
        else raise ValidationError, "Unknown browser skill method: #{method_name}"
        end
      end

      private

      attr_reader :client

      def dispatch(action, input)
        if client.respond_to?(:call)
          client.call(action, input)
        elsif client.respond_to?(action)
          client.public_send(action, **symbolize_keys(input))
        else
          raise ValidationError, "browser client must respond to #call or ##{action}"
        end
      end

      def text_result(value)
        return { "text" => value } if value.is_a?(String)

        text = fetch_value(value, "text")
        raise ValidationError, "browser text result must include a text String" unless text.is_a?(String)

        { "text" => text }
      end

      def links_result(value)
        raise ValidationError, "browser links result must be an Array" unless value.is_a?(Array)

        value.map do |link|
          href = fetch_value(link, "href")
          text = fetch_value(link, "text") || ""
          raise ValidationError, "browser link href must be a String" unless href.is_a?(String)
          raise ValidationError, "browser link text must be a String" unless text.is_a?(String)

          { "href" => href, "text" => text }
        end
      end

      def snapshot_result(value)
        raise ValidationError, "browser snapshot result must be a Hash" unless value.is_a?(Hash)

        stringify_keys(value)
      end

      def fetch_url(input)
        url = fetch_value(input, "url")
        raise ValidationError, "url must be a String" unless url.is_a?(String)

        url
      end

      def fetch_value(hash, key)
        return nil unless hash.is_a?(Hash)

        hash[key] || hash[key.to_sym]
      end

      def stringify_keys(value)
        case value
        when Array then value.map { |item| stringify_keys(item) }
        when Hash then value.each_with_object({}) { |(key, nested), result| result[key.to_s] = stringify_keys(nested) }
        else value
        end
      end

      def symbolize_keys(hash)
        hash.transform_keys(&:to_sym)
      end
    end
  end
end
