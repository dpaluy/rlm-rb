# frozen_string_literal: true

require "dspy"

module RLM
  module Optimizer
    module DspyPresets
      DEFAULT_PRESETS = {
        "mipro_v2_light" => ["DSPy::Teleprompt::MIPROv2::AutoMode", :light],
        "mipro_v2_medium" => ["DSPy::Teleprompt::MIPROv2::AutoMode", :medium],
        "mipro_v2_heavy" => ["DSPy::Teleprompt::MIPROv2::AutoMode", :heavy]
      }.freeze

      @factories = {}

      module_function

      def available
        (DEFAULT_PRESETS.keys + @factories.keys).sort
      end

      def register(name, &factory)
        raise ArgumentError, "preset factory block is required" unless factory

        @factories[normalize(name)] = factory
      end

      def unregister(name)
        @factories.delete(normalize(name))
      end

      def build(name, metric: nil, **)
        preset_name = normalize(name)

        return @factories.fetch(preset_name).call(metric: metric, **) if @factories.key?(preset_name)

        build_default(preset_name, metric: metric, **)
      end

      def build_default(name, metric: nil, **)
        factory_path, method_name = DEFAULT_PRESETS.fetch(name) do
          raise ArgumentError, "Unknown dspy optimizer preset: #{name}"
        end

        constantize(factory_path).public_send(method_name, metric: metric, **)
      rescue NameError, LoadError => e
        raise LoadError, "dspy optimizer preset #{name} requires optional dspy optimizer support: #{e.message}"
      end

      def normalize(name)
        name.to_s.tr("-", "_")
      end

      def constantize(path)
        path.split("::").reject(&:empty?).inject(Object) do |namespace, constant_name|
          namespace.const_get(constant_name)
        end
      end
    end
  end
end
