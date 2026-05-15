# frozen_string_literal: true

require_relative "../../../rlm"

begin
  require "rails/generators/base" unless defined?(Rails::Generators::Base)
rescue LoadError
  nil
end

unless defined?(Rails::Generators::Base)
  raise RLM::ConfigurationError, "RLM::InstallGenerator requires Rails::Generators::Base to be loaded"
end

module RLM
  class InstallGenerator < Rails::Generators::Base
    source_root ::File.expand_path("templates", __dir__)

    def copy_initializer
      template "rlm.rb", "config/initializers/rlm.rb"
    end
  end
end
