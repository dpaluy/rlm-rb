# frozen_string_literal: true

module RuntimeTraceAssertions
  def event_types(result) = result.trace.events.map { |event| event[:type] }

  def expected_code_run_events
    %i[
      run_started validation_attempted budget_checked budget_checked
      root_prompt_created root_lm_called budget_checked budget_checked
      budget_checked code_generated validation_attempted budget_checked
      budget_checked sub_lm_called budget_checked validation_attempted
      output_submitted budget_checked code_executed budget_checked
      validation_attempted run_completed
    ]
  end

  def expected_budget_failure_events
    %i[
      run_started validation_attempted budget_checked budget_checked
      root_prompt_created root_lm_called budget_checked budget_checked
      budget_checked code_generated validation_attempted budget_checked
      budget_checked code_executed run_failed
    ]
  end

  def expected_validation_failure_events
    %i[
      run_started validation_attempted budget_checked budget_checked
      root_prompt_created root_lm_called budget_checked budget_checked
      validation_attempted validation_failed run_failed
    ]
  end

  def expected_parse_failure_events
    %i[
      run_started validation_attempted budget_checked budget_checked
      root_prompt_created root_lm_called budget_checked run_failed
    ]
  end

  def assert_budget_failure_trace(result)
    assert_equal :budget_exceeded, result.trace.events.last[:payload][:status]
    assert_equal "RLM::BudgetExceededError", result.trace.events.last[:payload][:error][:class]
  end

  def assert_budget_exhaustion_result(result)
    assert_equal :budget_exceeded, result.status
    assert result.failed?
    assert_equal 1, result.llm_calls
    assert_equal expected_budget_failure_events, event_types(result)
    assert_budget_failure_trace(result)
  end
end
