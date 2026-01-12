# frozen_string_literal: true

require_relative "lib/rbtree/version"

Gem::Specification.new do |spec|
  spec.name    = "rbtree-ruby"
  spec.version = RBTree::VERSION
  spec.authors = ["Masahito Suzuki"]
  spec.email   = ["firelzrd@gmail.com"]

  spec.summary     = "A pure Ruby implementation of Red-Black Tree with multi-value support"
  spec.description = <<~DESC
    RBTree is a pure Ruby implementation of the Red-Black Tree data structure,
    providing efficient ordered key-value storage with O(log n) operations.
    Includes MultiRBTree for handling duplicate keys with linked lists.
  DESC
  spec.homepage = "https://github.com/firelzrd/rbtree-ruby"
  spec.license  = "MIT"
  spec.required_ruby_version = ">= 3.0.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/firelzrd/rbtree-ruby"
  spec.metadata["changelog_uri"] = "https://github.com/firelzrd/rbtree-ruby/blob/main/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (File.expand_path(f) == __FILE__) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git .github appveyor Gemfile])
    end
  end
  
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # No runtime dependencies - pure Ruby implementation

  # Development dependencies
  # spec.add_development_dependency "rake", "~> 13.0"
  # spec.add_development_dependency "minitest", "~> 5.0"
  # spec.add_development_dependency "rdoc", "~> 6.0"
end
