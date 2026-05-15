# frozen_string_literal: true

module RLM
  class Context
    SANDBOX_FILES_ROOT = "rlm_files"

    attr_reader :inputs, :files

    def initialize(inputs: {}, files: [])
      @inputs = inputs.dup.freeze
      @files = Array(files).dup.freeze
      @handles = build_handles(@files)
    end

    def manifest
      {
        files: @files.map do |file|
          handle = handle_for(file)
          {
            handle: handle,
            filename: file.filename,
            content_type: file.content_type,
            size_bytes: file.size_bytes,
            sandbox_path: ::File.join(SANDBOX_FILES_ROOT, handle, safe_filename(file.filename))
          }
        end,
        inputs: serializable_inputs
      }
    end

    def file_for(handle)
      @handles[handle]
    end

    def handle_for(file)
      @handles.key(file)
    end

    private

    def build_handles(files)
      files.each_with_index.to_h { |file, i| ["file_#{i + 1}", file] }
    end

    def serializable_inputs
      @inputs.each_with_object({}) do |(key, value), acc|
        acc[key] = value.is_a?(File) ? { file_handle: handle_for(value) } : value
      end
    end

    def safe_filename(filename)
      basename = ::File.basename(filename.to_s)
      basename.empty? || basename == "." ? "file" : basename
    end
  end
end
