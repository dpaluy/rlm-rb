# frozen_string_literal: true

require "test_helper"

class RLM::Skills::HTMLTest < Minitest::Test
  HTML_BODY = '<html><head><style>.x{}</style></head><body><h1>Hi &amp; bye</h1><a href="/x">Next</a></body></html>'

  def test_text_returns_visibleish_text
    file = RLM::File.from_text("page.html", HTML_BODY)
    context = RLM::Context.new(files: [file])

    text = RLM::Skills::HTML.new.call("text", { "handle" => "file_1" }, context: context, limits: RLM::Limits.new)

    assert_equal({ "text" => "Hi & bye Next" }, text)
  end

  def test_links_returns_href_and_label
    file = RLM::File.from_text("page.html", HTML_BODY)
    context = RLM::Context.new(files: [file])

    links = RLM::Skills::HTML.new.call("links", { "handle" => "file_1" }, context: context, limits: RLM::Limits.new)

    assert_equal [{ "href" => "/x", "text" => "Next" }], links
  end

  def test_rejects_unknown_method
    assert_raises(RLM::ValidationError) do
      RLM::Skills::HTML.new.call("missing", { "handle" => "file_1" }, context: RLM::Context.new, limits: RLM::Limits.new)
    end
  end
end
