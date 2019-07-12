# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'multiprocessing/version'

Gem::Specification.new do |gem|
  gem.name          = "multiprocessing"
  gem.version       = MultiProcessing::VERSION
  gem.authors       = ["clicube"]
  gem.email         = ["clicube@gmail.com"]
  gem.description   = %q{Classes for inter-process synchronization/communication like thread library in ruby standard library}
  gem.summary       = %q{Inter-process synchronization/communication}
  gem.homepage      = "https://github.com/clicube/multiprocessing"
  gem.license       = "MIT"


  gem.files         = `git ls-files`.split($/)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]
end
