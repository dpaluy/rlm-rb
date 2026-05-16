# frozen_string_literal: true

require_relative "../rlm"
require_relative "rails/active_storage"

module RLM
  module Rails
    module_function

    def configure_from_application(application)
      RLM.configure do |config|
        config.cache ||= application_cache(application)
        config.logger = ::Rails.logger if rails_logger?
      end
    end

    def application_cache(application)
      application.respond_to?(:cache) ? application.cache : nil
    end
    private_class_method :application_cache

    def rails_logger?
      defined?(::Rails) && ::Rails.respond_to?(:logger) && ::Rails.logger
    end
    private_class_method :rails_logger?
  end
end

require_relative "rails/railtie" if defined?(Rails::Railtie)
