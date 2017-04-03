# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'beebotte/version'

Gem::Specification.new do |spec|
  spec.name          = "beebotte"
  spec.version       = Beebotte::VERSION
  spec.authors       = ["Mike Kazmier"]
  spec.email         = ["dakazmier@gmail.com"]

  spec.summary       = "Beebotte REST API connector"
  spec.description   = "A pure ruby implementation of the BBT connector for beebotte's REST api"
  spec.homepage      = "https://github.com/DaKaZ/bbt_ruby"

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency 'openssl'
  spec.add_runtime_dependency 'json'
  spec.add_runtime_dependency 'rest-client', '>= 2.0.0'
  spec.add_runtime_dependency 'classy_hash'
  spec.add_runtime_dependency 'mqtt'
  spec.add_development_dependency "rspec"
  spec.add_development_dependency "rspec-nc"
  spec.add_development_dependency "guard"
  spec.add_development_dependency "guard-rspec"
  spec.add_development_dependency "pry"
  spec.add_development_dependency "webmock"
  spec.add_development_dependency "bundler", "~> 1.14"
  spec.add_development_dependency "rake", "~> 10.0"
end
