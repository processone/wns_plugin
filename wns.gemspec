# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "wns/version"

Gem::Specification.new do |s|
  s.name        = "wns"
  s.version     = "0.0.1"
  s.authors     = ["Juan Pablo Carlino"]
  s.email       = ["jpcarlino@process-one.net"]
  s.homepage    = "http://github.com/jpcarlino/"
  s.summary     = %q{send notifications to Windows Store applications on UWP devices}
  s.description = %q{wns is a service that helps developers send data from servers to their Windows Store apps on Universal Windows Platform devices.}
  s.license     = "MIT"

  s.rubyforge_project = "wns"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  s.add_dependency('httparty')
  s.add_dependency('json')
end
