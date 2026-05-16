# frozen_string_literal: true

class RlmPredictJob < ApplicationJob
  queue_as :default

  def perform(signature_class_name, input, options = {})
    signature = signature_class_name.constantize
    normalized_input = input.deep_symbolize_keys
    normalized_options = options.deep_symbolize_keys

    RLM.predict(signature, input: normalized_input, **normalized_options)
  end
end
