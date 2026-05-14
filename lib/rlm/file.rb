# frozen_string_literal: true

require "pathname"

module RLM
  class File
    CONTENT_TYPES = {
      ".txt" => "text/plain",
      ".md" => "text/markdown",
      ".markdown" => "text/markdown",
      ".csv" => "text/csv",
      ".json" => "application/json",
      ".pdf" => "application/pdf",
      ".html" => "text/html",
      ".htm" => "text/html",
      ".xml" => "application/xml",
      ".yml" => "application/yaml",
      ".yaml" => "application/yaml",
      ".rb" => "application/x-ruby"
    }.freeze

    DEFAULT_CONTENT_TYPE = "application/octet-stream"

    attr_reader :filename, :content_type, :size_bytes, :source

    def self.from_path(path)
      pathname = Pathname.new(path)
      raise ArgumentError, "File not found: #{path}" unless pathname.file?

      new(
        filename: pathname.basename.to_s,
        content_type: content_type_for(pathname.extname),
        size_bytes: pathname.size,
        source: { kind: :path, path: pathname.expand_path.to_s }
      )
    end

    def self.from_text(filename, text)
      raise ArgumentError, "filename is required" if filename.to_s.empty?

      new(
        filename: filename,
        content_type: content_type_for(::File.extname(filename)),
        size_bytes: text.bytesize,
        source: { kind: :text, text: text }
      )
    end

    def self.from_io(io, filename:, content_type: nil)
      raise ArgumentError, "filename is required" if filename.to_s.empty?

      data = io.read
      new(
        filename: filename,
        content_type: content_type || content_type_for(::File.extname(filename)),
        size_bytes: data.bytesize,
        source: { kind: :io, text: data }
      )
    end

    def self.from_active_storage(blob)
      raise ArgumentError, "blob cannot be nil" if blob.nil?

      new(
        filename: blob.filename.to_s,
        content_type: blob.content_type,
        size_bytes: blob.byte_size,
        source: { kind: :active_storage, blob: blob }
      )
    end

    def self.content_type_for(extname)
      CONTENT_TYPES[extname.to_s.downcase] || DEFAULT_CONTENT_TYPE
    end

    def initialize(filename:, content_type:, size_bytes:, source:)
      @filename = filename
      @content_type = content_type
      @size_bytes = size_bytes
      @source = source
    end

    def read
      case source[:kind]
      when :path then ::File.read(source[:path])
      when :text, :io then source[:text]
      when :active_storage then source[:blob].download
      else raise ConfigurationError, "Unknown file source kind: #{source[:kind].inspect}"
      end
    end

    def to_h
      {
        filename: filename,
        content_type: content_type,
        size_bytes: size_bytes,
        source_kind: source[:kind]
      }
    end
  end
end
