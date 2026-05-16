# frozen_string_literal: true

module RLM
  module Dashboard
    module_function

    def summary(records)
      rows = Array(records).map { |record| normalize(record) }
      {
        total_runs: rows.size,
        status_counts: status_counts(rows),
        total_cost_cents: rows.sum { |row| row[:cost_cents] },
        average_duration_ms: average(rows, :duration_ms),
        average_llm_calls: average(rows, :llm_calls),
        recent_runs: rows
      }
    end

    def normalize(record)
      {
        trace_id: value(record, :trace_id),
        status: value(record, :status).to_s,
        cost_cents: integer_value(record, :cost_cents),
        duration_ms: integer_value(record, :duration_ms),
        llm_calls: integer_value(record, :llm_calls),
        iterations: integer_value(record, :iterations),
        error_message: value(record, :error_message) || value(record, :error),
        output: value(record, :output)
      }
    end
    private_class_method :normalize

    def status_counts(rows)
      rows.each_with_object(Hash.new(0)) { |row, counts| counts[row[:status]] += 1 }.to_h
    end
    private_class_method :status_counts

    def average(rows, key)
      return 0 if rows.empty?

      rows.sum { |row| row[key] }.fdiv(rows.size).round(2)
    end
    private_class_method :average

    def integer_value(record, key)
      value(record, key).to_i
    end
    private_class_method :integer_value

    def value(record, key)
      return result_value(record, key) if record.is_a?(RLM::Result)
      return record[key] if record.respond_to?(:key?) && record.key?(key)
      return record[key.to_s] if record.respond_to?(:key?) && record.key?(key.to_s)
      return record.public_send(key) if record.respond_to?(key)

      nil
    end
    private_class_method :value

    def result_value(result, key)
      return result.trace&.id if key == :trace_id
      return result.error&.message if key == :error_message

      result.public_send(key) if result.respond_to?(key)
    end
    private_class_method :result_value
  end
end
