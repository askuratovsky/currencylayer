require "bundler/gem_tasks"

desc 'Spec all functionality of gem'
task :spec do
  system("rspec spec")
end

task :default => :spec
task :test    => :spec

desc "Open an irb session preloaded with this library"
task :console do
  sh "irb -rubygems -I lib -r money/bank/currencylayer"
end