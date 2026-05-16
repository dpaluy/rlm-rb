# frozen_string_literal: true

module RLM
  module Rails
    module ActiveStorage
      module_function

      def file(attachable)
        blob = blob_for(attachable)
        raise ArgumentError, "active storage attachment is not attached" if blob.nil?

        RLM::File.from_active_storage(blob)
      end

      def files(attachables)
        return attachables.flat_map { |attachable| file_list(attachable) } if attachables.is_a?(Array)

        file_list(attachables)
      end

      def file_list(attachable)
        return attachable.attachments.map { |attachment| file(attachment) } if attachable.respond_to?(:attachments)
        return attachable.blobs.map { |blob| file(blob) } if attachable.respond_to?(:blobs)

        [file(attachable)]
      end
      private_class_method :file_list

      def blob_for(attachable)
        return nil if attachable.nil?
        return nil if attachable.respond_to?(:attached?) && !attachable.attached?
        return attachable.blob if attachable.respond_to?(:blob)

        attachable
      end
      private_class_method :blob_for
    end
  end
end
