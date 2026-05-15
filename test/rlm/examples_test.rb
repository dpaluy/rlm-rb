# frozen_string_literal: true

require "open3"
require "rbconfig"
require "test_helper"

class RLM::ExamplesTest < Minitest::Test
  EXAMPLE_PATH = File.expand_path("../../examples/plain_ruby_invoice_extraction.rb", __dir__)
  REPO_ROOT = File.expand_path("../..", __dir__)

  def test_plain_ruby_invoice_example_exists
    assert_path_exists EXAMPLE_PATH
  end

  def test_plain_ruby_invoice_example_parses
    _stdout, stderr, status = Open3.capture3(RbConfig.ruby, "-c", EXAMPLE_PATH, chdir: REPO_ROOT)

    assert status.success?, stderr
  end

  def test_plain_ruby_invoice_example_skips_without_opt_in_or_credentials
    stdout, stderr, status = run_example(
      "RLM_RUN_LIVE_EXAMPLE" => nil,
      "OPENAI_API_KEY" => nil,
      "ANTHROPIC_API_KEY" => nil,
      "GEMINI_API_KEY" => nil
    )

    assert status.success?, stderr
    assert_includes stdout, "Skipped live RLM example."
    assert_empty stderr
  end

  def test_plain_ruby_invoice_example_skips_without_opt_in_even_when_credentials_exist
    stdout, stderr, status = run_example(
      "RLM_RUN_LIVE_EXAMPLE" => nil,
      "OPENAI_API_KEY" => "dummy"
    )

    assert status.success?, stderr
    assert_includes stdout, "Skipped live RLM example."
    assert_empty stderr
  end

  private

  def run_example(env)
    Open3.capture3(env, RbConfig.ruby, EXAMPLE_PATH, chdir: REPO_ROOT)
  end
end
