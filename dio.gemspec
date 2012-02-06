# -*- encoding: utf-8 -*-
require File.expand_path('../lib/dio/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ["Daniel Bretoi"]
  gem.email         = ["nefar@otherware.org"]
  gem.description   = %q{TODO: Write a gem description}
  gem.summary       = %q{TODO: Write a gem summary}
  gem.homepage      = ""

  gem.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  gem.files         = `git ls-files`.split("\n")
  gem.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  gem.name          = "dio"
  gem.require_paths = ["lib"]
  gem.version       = Dio::VERSION

  gem.add_dependency 'rack'
  gem.add_dependency 'awesome_print'
  gem.add_dependency 'thin'
  gem.add_development_dependency 'quickie'
end
