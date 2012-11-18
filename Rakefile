#!/usr/bin/env rake
require "bundler/gem_tasks"
require 'rake/testtask'
include Rake::DSL

desc "Run tests"
task :test => ['test:unit', 'test:integration']

task :default => :test

namespace :test do
  Rake::TestTask.new :unit do |t|
    t.libs << 'test'
    t.pattern = 'test/unit/*_test.rb'
  end

  Rake::TestTask.new :integration do |t|
    t.libs << 'test'
    t.pattern = 'test/integration/*_test.rb'
  end
end



