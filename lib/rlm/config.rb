# frozen_string_literal: true

module RLM
  class Config
    attr_accessor :root_lm, :sub_lm, :sandbox, :cache, :default_limits, :trace_store
    attr_writer :logger

    def initialize
      @root_lm = nil
      @sub_lm = nil
      @sandbox = Sandbox::Mock.new
      @cache = nil
      @default_limits = Limits.new
      @trace_store = nil
      @logger = nil
    end

    def logger
      @logger ||= default_logger
    end

    private

    def default_logger
      if defined?(::Rails) && ::Rails.respond_to?(:logger) && ::Rails.logger
        ::Rails.logger
      else
        require "logger"
        ::Logger.new($stderr)
      end
    end
  end
end
