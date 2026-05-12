# frozen_string_literal: true

module RLM
  module Lm
    class Mock
      attr_reader :prompts, :cost_cents

      def initialize(responses:, cost_cents: 0)
        @responses = Array(responses).dup.freeze
        raise ArgumentError, "responses must not be empty" if @responses.empty?

        @cost_cents_per_call = cost_cents
        @cost_cents = 0
        @prompts = []
        @index = 0
      end

      def call(prompt:, **)
        raise ProviderError, "prompt must be a String" unless prompt.is_a?(String)
        raise ProviderError, "mock LM responses exhausted" if exhausted?

        prompts << prompt
        @cost_cents += @cost_cents_per_call

        response = @responses.fetch(@index)
        @index += 1
        response
      end

      def call_count
        prompts.length
      end

      def last_prompt
        prompts.last
      end

      private

      def exhausted?
        @index >= @responses.length
      end
    end
  end
end
