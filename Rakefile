# frozen_string_literal: true

require "bundler/gem_tasks"
require "rdoc/task"

RDoc::Task.new(:rdoc) do |rdoc|
  rdoc.rdoc_dir = "doc"
  rdoc.title    = "RBTree Documentation"
  rdoc.options << "--line-numbers"
  rdoc.rdoc_files.include("lib/**/*.rb")
  rdoc.rdoc_files.include("README.md")
  rdoc.rdoc_files.include("LICENSE")
end

desc "Build the gem"
task :build do
  sh "gem build rbtree-ruby.gemspec"
end

desc "Install the gem locally"
task :install => :build do
  sh "gem install ./rbtree-ruby-#{RBTree::VERSION}.gem"
end

desc "Clean build artifacts"
task :clean do
  sh "rm -f *.gem"
  sh "rm -rf doc/"
end

task :default => :rdoc
