# frozen_string_literal: true

module RLM
  class Runtime
    class Bridge
      module Skills
        def skill(skill_name, method_name, input_hash)
          input = ensure_json_value!(input_hash, "skill input")
          instance = find_skill(skill_name)
          raise ValidationError, "Unknown skill: #{skill_name}" if instance.nil?

          output = instance.call(method_name, input, context: context, limits: limits)
          ensure_json_value!(output, "skill output")
          trace.record(:skill_called, skill: skill_key(instance), method: method_name, input: input)
          output
        end

        private

        def find_skill(skill_name)
          skills.find { |instance| skill_key(instance) == skill_name.to_s }
        end

        def skill_key(instance)
          return instance.registry_name if instance.respond_to?(:registry_name)

          instance.class.name.split("::").last.downcase
        end
      end
    end
  end
end
