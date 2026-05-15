# frozen_string_literal: true

require "test_helper"

class RLM::TelemetryTest < Minitest::Test
  SpanRecorder = Struct.new(:spans) do
    def in_span(name, attributes: {})
      spans << { name: name, attributes: attributes }
      yield
    end
  end

  NotificationsRecorder = Struct.new(:events) do
    def instrument(name, payload)
      events << { name: name, payload: payload }
      yield
    end
  end

  def test_in_span_yields_without_tracer
    yielded = false

    RLM::Telemetry.new.in_span("rlm.test") { yielded = true }

    assert yielded
  end

  def test_in_span_delegates_to_tracer
    tracer = SpanRecorder.new([])

    result = RLM::Telemetry.new(tracer: tracer).in_span("rlm.test", attributes: { a: 1 }) { :ok }

    assert_equal :ok, result
    assert_equal [{ name: "rlm.test", attributes: { a: 1 } }], tracer.spans
  end

  def test_in_span_emits_active_support_notification_when_loaded
    recorder = NotificationsRecorder.new([])

    result = with_active_support_notifications(recorder) do
      RLM::Telemetry.new.in_span("rlm.test", attributes: { a: 1 }) { :ok }
    end

    assert_equal :ok, result
    assert_equal [{ name: "rlm.test", payload: { a: 1 } }], recorder.events
  end

  def test_in_span_emits_notification_and_tracer_span
    recorder = NotificationsRecorder.new([])
    tracer = SpanRecorder.new([])

    with_active_support_notifications(recorder) do
      RLM::Telemetry.new(tracer: tracer).in_span("rlm.test", attributes: { a: 1 }) { :ok }
    end

    assert_equal [{ name: "rlm.test", payload: { a: 1 } }], recorder.events
    assert_equal [{ name: "rlm.test", attributes: { a: 1 } }], tracer.spans
  end

  private

  def with_active_support_notifications(recorder)
    active_support_defined = Object.const_defined?(:ActiveSupport)
    previous_active_support = Object.const_get(:ActiveSupport) if active_support_defined
    Object.send(:remove_const, :ActiveSupport) if active_support_defined

    active_support = Module.new
    active_support.const_set(:Notifications, recorder)
    Object.const_set(:ActiveSupport, active_support)
    yield
  ensure
    Object.send(:remove_const, :ActiveSupport) if Object.const_defined?(:ActiveSupport)
    Object.const_set(:ActiveSupport, previous_active_support) if active_support_defined
  end
end
