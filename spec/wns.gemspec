# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "adm/version"

Gem::Specification.new do |s|
  s.name        = "adm"
  s.version     = "0.0.1"
  s.authors     = ["Juan Pablo Carlino", "Amro Mousa", "Kashif Rasul", "Shoaib Burq"]
  s.email       = ["jpcarlino@process-one.net", "amromousa@gmail.com", "kashif@spacialdb.com", "shoaib@spacialdb.com"]
  s.homepage    = "http://github.com/jpcarlino/adm"
  s.summary     = %q{send data to Android applications on Kindle Fire devices}
  s.description = %q{adm is a service that helps developers send data from servers to their Android applications on Amazon Kindle Fire devices.}
  s.license     = "MIT"

  s.rubyforge_project = "adm"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  s.add_dependency('httparty')
  s.add_dependency('json')
end
