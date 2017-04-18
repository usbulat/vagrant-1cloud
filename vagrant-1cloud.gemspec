# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'vagrant-1cloud/version'

Gem::Specification.new do |gem|
  gem.name          = "vagrant-1cloud"
  gem.version       = VagrantPlugins::OneCloud::VERSION
  gem.authors       = ["Bulat Yusupov"]
  gem.email         = ["usbulat@gmail.com"]
  gem.description   = %q{Enables Vagrant to manage 1cloud droplets. Based on https://github.com/devopsgroup-io/vagrant-digitalocean.}
  gem.summary       = gem.description

  gem.files         = `git ls-files`.split($/)
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]

  gem.add_dependency "faraday", ">= 0.8.6"
  gem.add_dependency "json"
  gem.add_dependency "log4r"
end