# frozen_string_literal: true

require "test_helper"

class RLM::CoreConstraintsTest < Minitest::Test
  def test_predict_public_api_shape_stays_stable
    assert_equal(
      [%i[req signature], %i[keyreq input], %i[keyrest **]],
      RLM.method(:predict).parameters
    )
  end

  def test_core_gem_does_not_depend_on_rails
    dependency_names = gemspec.dependencies.map(&:name)

    %w[rails railties activerecord activejob activestorage].each do |dependency|
      refute_includes dependency_names, dependency
    end
  end

  def test_core_gem_does_not_bundle_deferred_optional_runtime_dependencies
    dependency_names = gemspec.dependencies.map(&:name)

    %w[
      baml
      dspy-miprov2
      pdf-reader
      playwright-ruby-client
      selenium-webdriver
      tesseract-ocr
      wasmtime
    ].each do |dependency|
      refute_includes dependency_names, dependency
    end
  end

  def test_local_planning_docs_are_not_packaged
    refute_includes gemspec.files, "docs/prd.md"
    refute_includes gemspec.files, "docs/postponed-issues.md"
  end

  private

  def gemspec
    @gemspec ||= Gem::Specification.load(File.expand_path("../../rlm-rb.gemspec", __dir__))
  end
end
