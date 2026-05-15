# frozen_string_literal: true

require_relative "../errors"
require_relative "../signature"
require_relative "../trace"
require_relative "../tool_registry"
require_relative "tool_resolution"

module RLM
  class Runtime
    class Bridge
      include ToolResolution

      attr_reader :submitted_output

      def initialize(context:, trace:, runtime: nil, tools: [], signatures: {}, depth: 0)
        @runtime = runtime
        @context = context
        @trace = trace
        @tools = tools.is_a?(ToolRegistry) ? tools : Array(tools)
        @signatures = signatures
        @depth = depth
        @submitted_output = nil
      end

      def predict(signature_name, input_hash)
        input = ensure_json_value!(input_hash, "predict input")
        signature = find_signature(signature_name)
        raise ValidationError, "Unknown signature: #{signature_name}" if signature.nil?

        validate_signature_input!(signature, input)
        unless runtime.respond_to?(:predict_subcall)
          raise ValidationError, "runtime does not support recursive predict calls"
        end

        runtime.predict_subcall(signature, input, depth: depth + 1)
      end

      def tool(tool_name, input_hash)
        runtime.record_tool_attempt! if runtime.respond_to?(:record_tool_attempt!)
        input = ensure_json_value!(input_hash, "tool input")
        tool = find_tool(tool_name)
        raise ToolError, "Unknown tool: #{tool_name}" if tool.nil?
        raise ToolError, "Tool is not read-only: #{tool_name}" unless tool_class(tool).category == :read_only

        validate_tool_input!(tool, input)
        instance = tool_instance(tool)
        output = instance.call(**symbolize_keys(input))
        ensure_json_value!(output, "tool output")
        validate_tool_output!(tool, output)
        trace.record(:tool_called, tool: tool_class(tool).registry_name, input: input)
        output
      end

      def submit(output_hash)
        output = ensure_json_value!(output_hash, "submitted output")
        @submitted_output = output
        runtime.record_submitted_output(output) if runtime.respond_to?(:record_submitted_output)
        trace.record(:output_submitted, output: output)
        output
      end

      def read_file(handle)
        raise ValidationError, "file handle must be a String" unless handle.is_a?(String)

        file = context.file_for(handle)
        raise ValidationError, "Unknown file handle: #{handle}" if file.nil?

        content = file.read
        trace.record(:file_read, handle: handle, filename: file.filename, size_bytes: file.size_bytes)
        content
      end

      def list_files
        context.manifest[:files]
      end

      def log(message)
        raise ValidationError, "log message must be a String" unless message.is_a?(String)

        trace.record(:runtime_logged, message: message)
        nil
      end

      private

      attr_reader :runtime, :context, :trace, :tools, :signatures, :depth

      def find_signature(signature_name)
        signatures[signature_name] || signatures[signature_name.to_s] || signatures[signature_name.to_sym]
      end

      def validate_signature_input!(signature, input)
        trace.record(:validation_attempted, signature: signature_identifier(signature), direction: :input)
        errors = RLM::Signature.validate_input(signature, input)
        return if errors.empty?

        trace.record(:validation_failed, signature: signature_identifier(signature), direction: :input, errors: errors)
        raise ValidationError, errors.join(", ")
      end

      def signature_identifier(signature)
        return signature.name if signature.respond_to?(:name) && !signature.name.to_s.empty?

        signature.to_s
      end

      def ensure_json_value!(value, label)
        raise ValidationError, "#{label} must be JSON-serializable" unless json_value?(value)

        value
      end

      def json_value?(value)
        case value
        when String, Integer, Float, TrueClass, FalseClass, NilClass
          true
        when Array
          value.all? { |item| json_value?(item) }
        when Hash
          value.all? { |key, nested| json_key?(key) && json_value?(nested) }
        else
          false
        end
      end

      def json_key?(key)
        key.is_a?(String) || key.is_a?(Symbol)
      end

      def symbolize_keys(hash)
        hash.transform_keys(&:to_sym)
      end
    end
  end
end
