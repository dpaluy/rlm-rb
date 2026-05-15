# frozen_string_literal: true

require "json"

module RLM
  class Runtime
    module SubcallCache
      MISS = Object.new.freeze

      private

      def cached_runtime_call(type:, payload:)
        key = runtime_cache_key(type: type, payload: payload)
        cached = read_runtime_cache(key)
        return cached unless cached.equal?(MISS)

        output = yield
        write_runtime_cache(key, output)
        output
      end

      def cached_subcall(checked_signature, payload)
        key = subcall_cache_key(checked_signature, payload)
        cached = read_runtime_cache(key)
        return cached unless cached.equal?(MISS)

        output = yield
        write_runtime_cache(key, output)
        output
      end

      def runtime_cache_key(type:, payload:)
        JSON.generate(type: "rlm.#{type}.v1", input: normalize_cache_value(payload))
      end

      def subcall_cache_key(checked_signature, payload)
        JSON.generate(
          type: "rlm.subcall.v1",
          signature: Signature.name_for(checked_signature),
          input: normalize_cache_value(payload)
        )
      end

      def read_runtime_cache(key)
        return MISS if cache.nil?

        read_hash_cache(key) || read_fetch_cache(key) || read_object_cache(key)
      end

      def write_runtime_cache(key, output)
        return if cache.nil?

        if cache.is_a?(Hash)
          cache[key] = output
        elsif cache.respond_to?(:write)
          cache.write(key, output)
        end
      end

      def read_hash_cache(key)
        return unless cache.is_a?(Hash)

        cache.key?(key) ? cache[key] : MISS
      end

      def read_fetch_cache(key)
        cache.fetch(key) { MISS } if !cache.is_a?(Hash) && cache.respond_to?(:fetch)
      end

      def read_object_cache(key)
        return MISS unless cache.respond_to?(:read)

        value = cache.read(key)
        value.nil? ? MISS : value
      end

      def normalize_cache_value(value)
        case value
        when Hash
          value.keys.sort_by(&:to_s).to_h { |key| [key.to_s, normalize_cache_value(value.fetch(key))] }
        when Array
          value.map { |item| normalize_cache_value(item) }
        when Symbol
          value.to_s
        else
          value
        end
      end
    end
  end
end
