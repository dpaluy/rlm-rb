# frozen_string_literal: true

require "test_helper"
require_relative "fixtures"

class RLM::RuntimeNativeJSONTest < Minitest::Test
  include RuntimeFixtures

  class NativeLm
    attr_reader :calls, :cost_cents

    def initialize
      @calls = []
      @cost_cents = 0
    end

    def call(prompt:, signature:, signature_adapter:, depth:, response_protocol:)
      calls << {
        prompt: prompt,
        signature: signature,
        signature_adapter: signature_adapter,
        depth: depth,
        response_protocol: response_protocol
      }
      { "summary" => "native" }
    end
  end

  def test_native_json_protocol_completes_from_provider_hash
    lm = NativeLm.new

    result = RLM.predict(
      RootSignature,
      input: { text: "hello" },
      lm: lm,
      response_protocol: RLM::ResponseProtocol::NativeJSON,
      sandbox: tracking_sandbox
    )

    assert_predicate result, :success?
    assert_equal({ "summary" => "native" }, result.output)
    assert_equal RLM::ResponseProtocol::NativeJSON, lm.calls.first.fetch(:response_protocol)
    assert_equal RootSignature, lm.calls.first.fetch(:signature_adapter)
  end
end
