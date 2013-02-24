require 'bundler/gem_tasks'

task :default => :spec

#### RSpec Task####

require 'rspec/core/rake_task'

RSpec::Core::RakeTask.new(:spec, :name) do |t,task_args|
  t.pattern = "spec/**/#{task_args[:name]}_spec.rb" if task_args[:name]
  t.rspec_opts = "--color --order rand"
end


#### Yard Task ####

require 'yard'
require 'yard/rake/yardoc_task'

YARD::Rake::YardocTask.new("yard") do |t|
  t.options = ["--no-stats"]
  t.after = ->{ YARD::CLI::Stats.run("--list-undoc") }
end

