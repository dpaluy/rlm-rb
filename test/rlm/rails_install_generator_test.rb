# frozen_string_literal: true

require "test_helper"

class RLM::RailsInstallGeneratorTest < Minitest::Test
  def test_generator_copies_initializer_template
    with_stubbed_generator_base do
      require generator_path

      generator = RLM::InstallGenerator.new
      generator.copy_initializer
      generator.copy_trace_model
      generator.copy_trace_migration
      generator.copy_predict_job

      assert_generator_templates(generator.templates)
      assert File.directory?(RLM::InstallGenerator.source_root_path)
    end
  end

  def test_initializer_template_loads_optional_rails_integration
    template = File.read(File.expand_path(
                           "../../lib/generators/rlm/install/templates/rlm.rb",
                           __dir__
                         ))

    assert_includes template, 'require "rlm/rails"'
    assert_includes template, "config.root_lm = RLM::Lm::RubyLLM.new"
    assert_includes template, "config.sub_lm = RLM::Lm::RubyLLM.new"
    assert_includes template, "config.sandbox = RLM::Sandbox::Subprocess.new"
    assert_includes template, "config.cache ||= Rails.cache"
    assert_includes template, "config.trace_store = RLM::TraceStore::ActiveRecord.new(record_class: RlmTrace)"
  end

  def test_job_template_runs_predict_through_active_job
    template = File.read(File.expand_path(
                           "../../lib/generators/rlm/install/templates/rlm_predict_job.rb",
                           __dir__
                         ))

    assert_includes template, "class RlmPredictJob < ApplicationJob"
    assert_includes template, "queue_as :default"
    assert_includes template, "signature = signature_class_name.constantize"
    assert_includes template, "RLM.predict(signature, input: normalized_input, **normalized_options)"
  end

  private

  def assert_generator_templates(templates)
    assert_equal ["rlm.rb", "config/initializers/rlm.rb"], templates[0]
    assert_equal ["rlm_trace.rb", "app/models/rlm_trace.rb"], templates[1]
    assert_equal "create_rlm_traces.rb", templates[2][0]
    assert_match %r{\Adb/migrate/\d{14}_create_rlm_traces\.rb\z}, templates[2][1]
    assert_equal ["rlm_predict_job.rb", "app/jobs/rlm_predict_job.rb"], templates[3]
  end

  def with_stubbed_generator_base
    previous_rails = remove_rails_constant
    Object.const_set(:Rails, stubbed_rails)
    yield
  ensure
    RLM.send(:remove_const, :InstallGenerator) if RLM.const_defined?(:InstallGenerator, false)
    $LOADED_FEATURES.delete("#{generator_path}.rb")
    Object.send(:remove_const, :Rails) if Object.const_defined?(:Rails)
    Object.const_set(:Rails, previous_rails) if previous_rails
  end

  def stubbed_rails
    Module.new.tap do |rails|
      generators = Module.new
      generators.const_set(:Base, Class.new(StubGeneratorBase))
      rails.const_set(:Generators, generators)
    end
  end

  def remove_rails_constant
    return nil unless Object.const_defined?(:Rails)

    Object.const_get(:Rails).tap { Object.send(:remove_const, :Rails) }
  end

  def generator_path
    File.expand_path("../../lib/generators/rlm/install/install_generator", __dir__)
  end

  class StubGeneratorBase
    class << self
      attr_reader :source_root_path

      def source_root(path)
        @source_root_path = path
      end
    end

    attr_reader :templates

    def template(source, destination)
      (@templates ||= []) << [source, destination]
    end
  end
end
