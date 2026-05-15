# frozen_string_literal: true

require_relative "lib/rlm/version"

Gem::Specification.new do |spec|
  spec.name = "rlm-rb"
  spec.version = RLM::VERSION
  spec.authors = ["David Paluy"]
  spec.email = ["dpaluy@users.noreply.github.com"]

  spec.summary = "Ruby runtime spine for typed, sandbox-oriented, auditable AI jobs over large application context."
  spec.description = <<~DESC.strip
    RLM.rb is a Ruby runtime spine for Recursive Language Models. It runs bounded, typed, auditable AI jobs
    over files, records, and application context. RLM.rb includes RubyLLM provider access, a dspy.rb signature adapter,
    the recursive prompt loop, file/context mounting, recursive sub-LM calls, typed final output, budget controls,
    trace events, and a best-effort trace_store hook.
  DESC
  spec.homepage = "https://github.com/dpaluy/rlm-rb"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.3.0"

  spec.metadata["rubygems_mfa_required"] = "true"
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata["bug_tracker_uri"] = "#{spec.homepage}/issues"

  gemspec = File.basename(__FILE__)
  tracked_files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true)
  end
  working_tree_files = Dir.chdir(__dir__) do
    Dir[
      "lib/**/*",
      "examples/**/*",
      "docs/plain-ruby-usage.md",
      "docs/runtime-features.md",
      "docs/production.md",
      "README.md",
      "CHANGELOG.md",
      "LICENSE.txt"
    ].select { |path| File.file?(path) }
  end
  shipped_docs = %w[
    docs/plain-ruby-usage.md
    docs/runtime-features.md
    docs/production.md
  ]
  rejected_files = (tracked_files + working_tree_files).uniq.reject do |f|
    (f == gemspec) ||
      f.start_with?(*%w[
                      test/ spec/ bin/ Gemfile .gitignore .github/ .rubocop.yml
                      .agents/ AGENTS.md CLAUDE.md Rakefile .yardopts
                    ])
  end
  spec.files = rejected_files.reject { |f| f.start_with?("docs/") && !shipped_docs.include?(f) }
  spec.require_paths = ["lib"]
  spec.extra_rdoc_files = Dir["README.md", "CHANGELOG.md", "LICENSE.txt"]

  spec.add_dependency "bigdecimal", "~> 3.2"
  spec.add_dependency "dspy", "~> 1.0"
  spec.add_dependency "logger", "~> 1.6"
  spec.add_dependency "ruby_llm", "~> 1.15"
end
