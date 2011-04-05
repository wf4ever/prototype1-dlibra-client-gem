# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{dlibra_client}
  s.version = "0.0.2"

  s.required_rubygems_version = Gem::Requirement.new(">= 1.2") if s.respond_to? :required_rubygems_version=
  s.authors = ["Stian Soiland-Reyes", "Jiten Bhagat"]
  s.summary = %q{Client library for the dLibra api of wf4ever Prototype 1 ROSRS}
  s.description = %q{Client library for the dLibra api of wf4ever Prototype 1 ROSRS}
  s.email = [ 'soiland-reyes@cs.manchester.ac.uk', 'jits@cs.man.ac.uk' ]
  s.extra_rdoc_files = [ "README" ]
  s.files = Dir.glob('{lib,spec}/**/*') + ["Manifest", "README", "Rakefile", "dlibra_client.gemspec"]
  s.homepage = %q{http://github.com/wf4ever/prototype1-dlibra-client-gem/}
  s.rdoc_options = ["--line-numbers", "--inline-source", "--title", "Dlibra_client", "--main", "README"]
  s.require_paths = ["lib"]
  s.rubyforge_project = %q{dlibra_client}
  s.rubygems_version = %q{1.6.2}
  s.test_files = Dir.glob('spec/**/*')

  s.add_runtime_dependency 'rdf', '~> 0.3'
  s.add_runtime_dependency 'rdf-rdfxml', '~> 0.3'
    
  s.add_development_dependency 'rspec', '~> 2.5'
  s.add_development_dependency 'uuidtools', '~> 2.1'
  s.add_development_dependency 'echoe', '~> 4.5'
  s.add_development_dependency 'fuubar', '~> 0.0.4'
  s.add_development_dependency 'zip', '~> 2.0'
  
  if s.respond_to? :specification_version then
    s.specification_version = 3

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
    else
    end
  else
  end
end
