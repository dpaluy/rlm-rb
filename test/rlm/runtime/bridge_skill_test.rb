# frozen_string_literal: true

require "test_helper"
require_relative "bridge_fixtures"

class RLM::Runtime::BridgeSkillTest < Minitest::Test
  include RuntimeBridgeFixtures

  def test_skill_dispatches_and_records_trace
    file = RLM::File.from_text("totals.csv", "name,total\nAcme,10\n")
    trace = RLM::Trace.new
    bridge = build_bridge(
      context: RLM::Context.new(files: [file]),
      trace: trace,
      skills: [RLM::Skills::CSV.new]
    )

    rows = bridge.skill("csv", "rows", { "handle" => "file_1" })

    assert_equal [{ "name" => "Acme", "total" => "10" }], rows
    assert_equal :skill_called, trace.events.last[:type]
    assert_equal "csv", trace.events.last[:payload][:skill]
  end

  def test_skill_rejects_unknown_skill
    bridge = build_bridge

    assert_raises(RLM::ValidationError) do
      bridge.skill("missing", "rows", {})
    end
  end
end
