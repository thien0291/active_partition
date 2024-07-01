# frozen_string_literal: true

require_relative "lib/active_partition/version"

Gem::Specification.new do |spec|
  spec.name          = "active_partition"
  spec.version       = ActivePartition::VERSION
  spec.authors       = ["Thien Tran"]
  spec.email         = ["webmaster3t@gmail.com"]

  spec.summary       = "An extension to ActiveRecord to support partitioned tables."
  spec.description   = "Applying partition with flexible and risk-free by auto generate partitioned tables, manage partitions directly from ActiveRecord models."
  spec.homepage      = "https://github.com/thien0291/active_partition"
  spec.license       = "MIT"
  spec.required_ruby_version = ">= 2.4.0"

  spec.metadata["allowed_push_host"] = "TODO: Set to 'https://mygemserver.com'"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/thien0291/active_partition"
  spec.metadata["changelog_uri"] = "https://github.com/thien0291/active_partition"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{\A(?:test|spec|features)/}) }
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Uncomment to register a new dependency of your gem
  spec.add_development_dependency "byebug", "~> 11.1.3"
  spec.add_development_dependency "pg", "~> 1.5.6"
  spec.add_development_dependency "rubocop", "~> 1.63.4"
  spec.add_development_dependency "rubocop-packaging"
  spec.add_development_dependency "rubocop-performance"
  spec.add_development_dependency "rubocop-rails"
  spec.add_development_dependency "rubocop-factory_bot", "~> 2.26"
  spec.add_development_dependency "rubocop-md"
  spec.add_dependency "rails"
  spec.add_dependency "rspec-rails"
  spec.add_dependency "range_operators", "~> 0.1.1"

  # For more information and examples about making a new gem, checkout our
  # guide at: https://bundler.io/guides/creating_gem.html
end
