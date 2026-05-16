# frozen_string_literal: true

require "test_helper"

class RLM::Skills::BrowserTest < Minitest::Test
  FakeClient = Class.new do
    attr_reader :calls

    def initialize
      @calls = []
    end

    def call(action, input)
      @calls << [action, input]
      case action
      when "text" then { text: "Rendered #{input.fetch("url")}" }
      when "links" then [{ href: "/next", text: "Next" }]
      when "snapshot" then { title: "Page", links: [{ href: "/next" }] }
      end
    end
  end

  MethodClient = Class.new do
    def text(url:)
      "Rendered #{url}"
    end
  end

  def test_text_uses_callable_client
    client = FakeClient.new
    result = skill(client).call("text", { "url" => "https://example.test" }, context: context)

    assert_equal({ "text" => "Rendered https://example.test" }, result)
    assert_equal [["text", { "url" => "https://example.test" }]], client.calls
  end

  def test_text_can_use_method_client
    result = skill(MethodClient.new).call("text", { "url" => "https://example.test" }, context: context)

    assert_equal({ "text" => "Rendered https://example.test" }, result)
  end

  def test_links_are_normalized_to_string_keys
    result = skill(FakeClient.new).call("links", { "url" => "https://example.test" }, context: context)

    assert_equal [{ "href" => "/next", "text" => "Next" }], result
  end

  def test_snapshot_stringifies_nested_keys
    result = skill(FakeClient.new).call("snapshot", { "url" => "https://example.test" }, context: context)

    assert_equal({ "title" => "Page", "links" => [{ "href" => "/next" }] }, result)
  end

  def test_rejects_unknown_method
    assert_raises(RLM::ValidationError) do
      skill(FakeClient.new).call("missing", { "url" => "https://example.test" }, context: context)
    end
  end

  def test_rejects_missing_url
    assert_raises(RLM::ValidationError) do
      skill(FakeClient.new).call("text", {}, context: context)
    end
  end

  private

  def skill(client)
    RLM::Skills::Browser.new(client: client)
  end

  def context
    RLM::Context.new
  end
end
