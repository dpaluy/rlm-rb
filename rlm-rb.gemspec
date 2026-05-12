# frozen_string_literal: true

require_relative "lib/rlm/version"

Gem::Specification.new do |spec|
  spec.name = "rlm-rb"
  spec.version = RLM::VERSION
  spec.authors = ["David Paluy"]
  spec.email = ["dpaluy@users.noreply.github.com"]

  spec.summary = "Ruby/Rails-native runtime for typed, sandboxed, auditable AI jobs over large application context."
  spec.description = <<~DESC.strip
    RLM.rb is a Ruby/Rails-native runtime for Recursive Language Models. It runs bounded, typed, auditable AI jobs
    over large files, records, and application context. RLM.rb uses RubyLLM for provider access and dspy.rb for
    typed signatures, and adds the missing recursive execution runtime: sandbox, REPL loop, file/context mounting,
    recursive sub-LM calls, typed final output, budget controls, and durable trajectories.
  DESC
  spec.homepage = "https://github.com/dpaluy/rlm-rb"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2.0"

  spec.metadata["rubygems_mfa_required"] = "true"
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata["bug_tracker_uri"] = "#{spec.homepage}/issues"

  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[
                        test/ spec/ bin/ Gemfile .gitignore .github/ .rubocop.yml
                        docs/ .agents/ AGENTS.md CLAUDE.md Rakefile .yardopts
                      ])
    end
  end
  spec.require_paths = ["lib"]
  spec.extra_rdoc_files = Dir["README.md", "CHANGELOG.md", "LICENSE.txt"]

  spec.add_dependency "logger", "~> 1.6"
end
