# frozen_string_literal: true

require_relative "../../sandbox/context_limits"

module RLM
  class Runtime
    class Bridge
      module Files
        def read_file(handle)
          file = context_file(handle)
          content = file.read
          Sandbox::ContextLimits.new(context: context, limits: limits).validate_file_content!(file, content)
          trace.record(:file_read, handle: handle, filename: file.filename, size_bytes: file.size_bytes)
          content
        end

        def list_files
          context.manifest[:files]
        end

        private

        def context_file(handle)
          raise ValidationError, "file handle must be a String" unless handle.is_a?(String)

          file = context.file_for(handle)
          raise ValidationError, "Unknown file handle: #{handle}" if file.nil?

          file
        end
      end
    end
  end
end
