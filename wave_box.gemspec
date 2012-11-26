# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "wave_box/version"

Gem::Specification.new do |s|
  s.name        = "wave-box"
  s.version     = WaveBox::VERSION
  s.authors     = ["Poga Po"]
  s.email       = ["poga.bahamut@gmail.com"]
  s.homepage    = ""
  s.summary     = %q{Redis-based Push-style messaging}
  s.description = %q{A simple push style messaging based on redis}

  s.rubyforge_project = "wavebox"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]
  s.licenses      = "MIT"

  # specify any dependencies here; for example:
  # s.add_development_dependency "rspec"
  s.add_runtime_dependency "redis"
end
