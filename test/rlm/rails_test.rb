# frozen_string_literal: true

require "test_helper"

class RLM::RailsTest < Minitest::Test
  include TestConfig

  def test_rails_require_is_safe_without_rails
    without_rails_constant do
      require rails_path

      refute defined?(RLM::Rails::Railtie)
    end
  end

  def test_railtie_configures_cache_and_logger_from_application
    with_stubbed_rails do
      application = Struct.new(:cache).new(:rails_cache)

      require rails_path
      RLM::Rails::Railtie.initializers.fetch("rlm.configure").call(application)

      assert_equal :rails_cache, RLM.config.cache
      assert_equal :rails_logger, RLM.config.logger
    end
  end

  def test_railtie_does_not_replace_existing_cache
    with_stubbed_rails do
      RLM.config.cache = :existing_cache

      require rails_path
      RLM::Rails::Railtie.initializers.fetch("rlm.configure").call(Struct.new(:cache).new(:rails_cache))

      assert_equal :existing_cache, RLM.config.cache
    end
  end

  private

  def without_rails_constant
    previous = remove_rails_constant
    clear_rlm_rails
    yield
  ensure
    clear_rlm_rails
    restore_rails_constant(previous)
  end

  def with_stubbed_rails
    previous = remove_rails_constant
    clear_rlm_rails
    rails = stubbed_rails
    Object.const_set(:Rails, rails)
    yield
  ensure
    clear_rlm_rails
    restore_rails_constant(previous)
  end

  def stubbed_rails
    Module.new.tap do |rails|
      railtie = Class.new do
        @initializers = {}

        class << self
          def initializers
            @initializers ||= {}
          end

          def initializer(name, &block)
            initializers[name] = block
          end
        end
      end
      rails.singleton_class.attr_accessor :logger
      rails.logger = :rails_logger
      rails.const_set(:Railtie, railtie)
    end
  end

  def remove_rails_constant
    return nil unless Object.const_defined?(:Rails)

    Object.const_get(:Rails).tap { Object.send(:remove_const, :Rails) }
  end

  def restore_rails_constant(previous)
    Object.send(:remove_const, :Rails) if Object.const_defined?(:Rails)
    Object.const_set(:Rails, previous) if previous
  end

  def clear_rlm_rails
    RLM.send(:remove_const, :Rails) if RLM.const_defined?(:Rails, false)

    $LOADED_FEATURES.delete("#{rails_path}.rb")
    $LOADED_FEATURES.delete(File.expand_path("../../lib/rlm/rails/railtie.rb", __dir__))
  end

  def rails_path
    File.expand_path("../../lib/rlm/rails", __dir__)
  end
end
