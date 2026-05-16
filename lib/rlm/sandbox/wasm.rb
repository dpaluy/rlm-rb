# frozen_string_literal: true

require_relative "remote"

module RLM
  module Sandbox
    class Wasm < Remote
      def initialize(runtime:)
        super(client: runtime)
      end
    end
  end
end
