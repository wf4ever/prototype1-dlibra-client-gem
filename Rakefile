require 'rubygems'
require 'rake'
require 'echoe'
require 'rspec/core/rake_task'


Echoe.new('dlibra_client', '0.2.2') do |p|
  p.description    = "Client library for the dLibra api of wf4ever Prototype 1 ROSRS"
  p.url            = "http://github.com/wf4ever/prototype1-dlibra-client-gem/"
  p.author         = "Stian Soiland-Reyes"
  p.email          = "soiland-reyes@cs.manchester.ac.uk"
  p.ignore_pattern = ["tmp/*", "script/*"]
  p.development_dependencies = []
end



RSpec::Core::RakeTask.new(:spec)

task :default => :spec

