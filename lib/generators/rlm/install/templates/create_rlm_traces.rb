# frozen_string_literal: true

class CreateRlmTraces < ActiveRecord::Migration[7.0]
  def change
    create_table :rlm_traces do |t|
      t.string :trace_id, null: false
      t.string :status, null: false
      t.json :output
      t.text :error_message
      t.integer :cost_cents, null: false, default: 0
      t.integer :duration_ms, null: false, default: 0
      t.integer :llm_calls, null: false, default: 0
      t.integer :iterations, null: false, default: 0
      t.json :validation_errors, null: false, default: []
      t.json :trace, null: false, default: {}

      t.timestamps
    end

    add_index :rlm_traces, :trace_id, unique: true
    add_index :rlm_traces, :status
  end
end
