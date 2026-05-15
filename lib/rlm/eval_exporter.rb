# frozen_string_literal: true

require "json"

module RLM
  class EvalExporter
    def self.examples(records, expected_output: nil, metadata: {})
      Array(records).map do |record|
        case record
        when Result
          EvalExample.from_result(record, expected_output: expected_output, metadata: metadata)
        when Trace
          EvalExample.from_trace(record, expected_output: expected_output, metadata: metadata)
        else
          raise ArgumentError, "expected RLM::Result or RLM::Trace, got #{record.class}"
        end
      end
    end

    def self.to_jsonl(records, expected_output: nil, metadata: {})
      examples(records, expected_output: expected_output, metadata: metadata)
        .map { |example| JSON.generate(example.to_h) }
        .join("\n")
    end
  end
end
