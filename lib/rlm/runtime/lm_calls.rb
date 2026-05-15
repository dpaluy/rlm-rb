# frozen_string_literal: true

module RLM
  class Runtime
    module LmCalls
      private

      def call_root_lm
        ensure_llm_budget!
        prompt = PromptBuilder.build(
          signature,
          input: input,
          context: context,
          limits: limits,
          skills: skills,
          response_protocol: response_protocol
        )
        trace.record(:root_prompt_created, bytes: prompt.bytesize)
        response = call_lm(lm, :root_lm_called, signature, prompt, depth)
        CodeExtractor.extract(response, protocol: response_protocol)
      end

      def call_sub_lm(checked_signature, payload, sub_depth)
        ensure_llm_budget!
        ensure_sub_lm_budget!
        prompt = PromptBuilder.build(
          checked_signature,
          input: payload,
          context: context,
          limits: limits,
          skills: skills,
          response_protocol: response_protocol
        )
        response = call_lm(sub_lm, :sub_lm_called, checked_signature, prompt, sub_depth)
        @sub_lm_calls += 1
        CodeExtractor.extract(response, protocol: response_protocol)
      end

      def call_lm(candidate, event_type, checked_signature, prompt, call_depth)
        name = Signature.name_for(checked_signature)
        before_cost = candidate.cost_cents if candidate.respond_to?(:cost_cents)
        response = telemetry.in_span("rlm.lm_call", attributes: { signature: name, depth: call_depth }) do
          candidate.call(prompt: prompt, signature: name, depth: call_depth)
        end
        @llm_calls += 1
        payload = {
          signature: name,
          cost_cents: cost_delta(candidate, before_cost)
        }
        payload[:usage] = candidate.last_usage if candidate.respond_to?(:last_usage) && candidate.last_usage
        trace.record(event_type, payload)
        ensure_cost_budget!
        response
      end
    end
  end
end
