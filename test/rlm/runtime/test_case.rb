# frozen_string_literal: true

require "test_helper"
require_relative "fixtures"
require_relative "trace_assertions"

class RuntimeTestCase < Minitest::Test
  include RuntimeFixtures
  include RuntimeTraceAssertions
end
