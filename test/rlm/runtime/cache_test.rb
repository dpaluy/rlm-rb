# frozen_string_literal: true

require_relative "test_case"

class RLM::RuntimeCacheTest < RuntimeTestCase
  def test_cache_reuses_file_reads
    file = counting_file("notes.txt", "hello")
    response = '<rlm-code>read_file("file_1"); read_file("file_1"); submit({ "summary" => "done" })</rlm-code>'

    result = RLM.predict(
      RootSignature,
      input: { text: "hello", notes: file },
      lm: RLM::Lm::Mock.new(responses: [response]),
      sandbox: tracking_sandbox,
      cache: {}
    )

    assert result.success?, result.error&.message
    assert_equal 1, file.reads
  end

  def test_cache_reuses_tool_outputs
    tool = counting_tool
    response = <<~RESPONSE
      <rlm-code>tool("CountingTool", {}); tool("CountingTool", {}); submit({ "summary" => "done" })</rlm-code>
    RESPONSE

    result = RLM.predict(
      RootSignature,
      input: { text: "hello" },
      lm: RLM::Lm::Mock.new(responses: [response]),
      sandbox: tracking_sandbox,
      tools: [tool],
      cache: {}
    )

    assert result.success?, result.error&.message
    assert_equal 1, tool.calls
  end

  def test_cache_reuses_skill_outputs
    skill = counting_skill
    response = <<~RESPONSE
      <rlm-code>
        skill("counting", "value", {})
        skill("counting", "value", {})
        submit({ "summary" => "done" })
      </rlm-code>
    RESPONSE

    result = RLM.predict(
      RootSignature,
      input: { text: "hello" },
      lm: RLM::Lm::Mock.new(responses: [response]),
      sandbox: tracking_sandbox,
      skills: [skill],
      cache: {}
    )

    assert result.success?
    assert_equal 1, skill.calls
  end

  private

  def counting_file(filename, text)
    Class.new(RLM::File) do
      attr_reader :reads

      define_method(:initialize) do
        @reads = 0
        super(
          filename: filename,
          content_type: "text/plain",
          size_bytes: text.bytesize,
          source: { kind: :text, text: text }
        )
      end

      def read
        @reads += 1
        super
      end
    end.new
  end

  def counting_tool
    Class.new(RLM::Tool) do
      attr_reader :calls

      def self.registry_name = "CountingTool"

      def initialize
        super
        @calls = 0
      end

      def call
        @calls += 1
        { "ok" => true }
      end
    end.new
  end

  def counting_skill
    Class.new(RLM::Skill) do
      attr_reader :calls

      def self.registry_name = "counting"

      def initialize
        super
        @calls = 0
      end

      def call(*, **)
        @calls += 1
        { "ok" => true }
      end
    end.new
  end
end
