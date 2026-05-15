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

    refute_includes dependency_names, "rails"
    refute_includes dependency_names, "railties"
    refute_includes dependency_names, "activerecord"
    refute_includes dependency_names, "activejob"
    refute_includes dependency_names, "activestorage"
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
