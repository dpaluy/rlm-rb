# frozen_string_literal: true

require_relative "item"

module RLM
  module Review
    class MemoryQueue
      def initialize
        @items = {}
      end

      def enqueue(result, reasons:, metadata: {})
        item = Item.new(result: result, reasons: reasons, metadata: metadata)
        @items[item.id] = item
        item
      end

      def fetch(id)
        @items[id]
      end

      def all
        @items.values
      end

      def pending
        all.select(&:pending?)
      end

      def resolve(id, decision:, reviewer: nil, notes: nil)
        item = fetch(id)
        raise ArgumentError, "Unknown review item: #{id.inspect}" unless item

        item.resolve(decision: decision, reviewer: reviewer, notes: notes)
      end
    end
  end
end
