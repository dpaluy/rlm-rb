# frozen_string_literal: true

require "bigdecimal"

module RLM
  module Lm
    class RubyLLM
      attr_reader :cost_cents, :last_usage, :call_count

      def initialize(model: nil, chat_factory: nil)
        @model = model
        @chat_factory = chat_factory
        @cost_cents = 0
        @last_usage = nil
        @call_count = 0
      end

      def call(prompt:, signature:, depth:, response_protocol: nil, signature_adapter: nil)
        raise ProviderError, "prompt must be a String for #{signature} at depth #{depth}" unless prompt.is_a?(String)

        response = configured_chat(response_protocol, signature_adapter).ask(prompt)
        content = response_content(response, response_protocol)
        cost_delta = response_cost_cents(response)

        @cost_cents += cost_delta
        @last_usage = usage_payload(response, cost_delta)
        @call_count += 1

        content
      rescue ProviderError
        raise
      rescue StandardError => e
        raise ProviderError, "RubyLLM provider call failed: #{e.message}"
      end

      private

      attr_reader :model, :chat_factory

      def build_chat
        return chat_factory.call if chat_factory

        require "ruby_llm"

        model ? ::RubyLLM.chat(model: model) : ::RubyLLM.chat
      end

      def configured_chat(response_protocol, signature_adapter)
        chat = build_chat
        schema = native_schema(response_protocol, signature_adapter)
        schema ? chat.with_schema(schema) : chat
      end

      def native_schema(response_protocol, signature_adapter)
        return unless response_protocol.respond_to?(:native_schema)
        raise ProviderError, "native response protocol requires signature adapter" if signature_adapter.nil?

        response_protocol.native_schema(signature_adapter)
      end

      def response_content(response, response_protocol)
        content = response.respond_to?(:content) ? response.content : response.to_s
        return content if response_protocol.respond_to?(:native_schema) && content.is_a?(Hash)

        raise ProviderError, "RubyLLM response content must be a String" unless content.is_a?(String)

        content
      end

      def usage_payload(response, cost_delta)
        {
          model_id: value_from(response, :model_id),
          input_tokens: token_value(response, :input),
          output_tokens: token_value(response, :output),
          cache_read_tokens: token_value(response, :cache_read),
          cache_write_tokens: token_value(response, :cache_write),
          thinking_tokens: token_value(response, :thinking),
          cost_cents: cost_delta,
          cost_known: response_cost_known?(response)
        }.compact
      end

      def token_value(response, key)
        tokens = value_from(response, :tokens)
        value_from(tokens, key)
      end

      def response_cost_cents(response)
        total = response_cost_total(response)
        return 0 if total.nil?

        (BigDecimal(total.to_s) * 100).round(0).to_i
      end

      def response_cost_known?(response)
        !response_cost_total(response).nil?
      end

      def response_cost_total(response)
        cost = value_from(response, :cost)
        value_from(cost, :total)
      end

      def value_from(object, key)
        return if object.nil?
        return object[key] if object.is_a?(Hash) && object.key?(key)
        return object[key.to_s] if object.is_a?(Hash) && object.key?(key.to_s)
        return object.public_send(key) if object.respond_to?(key)

        nil
      end
    end
  end
end
