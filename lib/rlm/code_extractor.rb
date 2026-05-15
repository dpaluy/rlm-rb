# frozen_string_literal: true

require_relative "response_protocol"

module RLM
  class CodeExtractor
    class Result
      attr_reader :type, :content

      def initialize(type:, content:)
        unless ResponseProtocol::TYPES.include?(type)
          raise ArgumentError, "Unknown code extraction result type: #{type.inspect}"
        end

        @type = type
        @content = content
      end

      def code?
        type == :code
      end

      def final?
        type == :final
      end

      def to_h
        {
          type: type,
          content: content
        }
      end
    end

    def self.extract(response, protocol: ResponseProtocol::DEFAULT)
      new(protocol: protocol).extract(response)
    end

    def initialize(protocol: ResponseProtocol::DEFAULT)
      @protocol = protocol
    end

    def extract(response)
      parsed = protocol.extract(response)
      Result.new(type: parsed.fetch(:type), content: parsed.fetch(:content))
    end

    private

    attr_reader :protocol
  end
end
