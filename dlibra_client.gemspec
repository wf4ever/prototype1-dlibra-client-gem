# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{dlibra_client}
  s.version = "0.0.1"

  s.required_rubygems_version = Gem::Requirement.new(">= 1.2") if s.respond_to? :required_rubygems_version=
  s.authors = ["Stian Soiland-Reyes"]
  s.cert_chain = ["/home/stain/.gem-certs/gem-public_cert.pem"]
  s.date = %q{2011-03-23}
  s.description = %q{Client library for the dLibra api of wf4ever Prototype 1 ROSRS}
  s.email = %q{soiland-reyes@cs.manchester.ac.uk}
  s.extra_rdoc_files = ["README", "lib/dlibra_client.rb"]
  s.files = ["Manifest", "README", "Rakefile", "dlibra_client.gemspec", "lib/dlibra_client.rb", "spec/dlibra_client_spec.rb", "spec/spec.opts", "spec/spec_helper.rb"]
  s.homepage = %q{http://github.com/wf4ever/prototype1-dlibra-client-gem/}
  s.rdoc_options = ["--line-numbers", "--inline-source", "--title", "Dlibra_client", "--main", "README"]
  s.require_paths = ["lib"]
  s.rubyforge_project = %q{dlibra_client}
  s.rubygems_version = %q{1.6.2}
  s.signing_key = %q{/home/stain/.gem-certs/gem-private_key.pem}
  s.summary = %q{Client library for the dLibra api of wf4ever Prototype 1 ROSRS}

  if s.respond_to? :specification_version then
    s.specification_version = 3

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
    else
    end
  else
  end
end
