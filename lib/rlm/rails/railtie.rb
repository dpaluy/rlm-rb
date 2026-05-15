# frozen_string_literal: true

require_relative "../rails" unless defined?(RLM::Rails)

unless defined?(Rails::Railtie)
  raise RLM::ConfigurationError, "RLM::Rails::Railtie requires Rails::Railtie to be loaded"
end

module RLM
  module Rails
    class Railtie < ::Rails::Railtie
      initializer "rlm.configure" do |application|
        RLM::Rails.configure_from_application(application)
      end
    end
  end
end
