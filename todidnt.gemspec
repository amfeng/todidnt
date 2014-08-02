$:.unshift(File.join(File.dirname(__FILE__), 'lib'))
require 'todidnt/version'

Gem::Specification.new do |s|
  s.name        = 'todidnt'
  s.version     = Todidnt::VERSION
  s.summary     = 'Todidnt'
  s.description = "Todidnt finds and dates todos in your git repository."
  s.authors     = ["Amber Feng"]
  s.email       = 'amber.feng@gmail.com'

  s.add_dependency('chronic', '0.10.2')
  s.add_dependency('launchy', '2.4.2')
  s.add_dependency('tilt', '2.0.1')
  s.add_dependency('slop', '3.6.0')
  s.add_dependency('subprocess', '1.0.0')

  s.add_development_dependency('minitest', '5.4.0')
  s.add_development_dependency('mocha', '1.1.0')

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- test/test_*.rb`.split("\n")
  s.executables   = ['todidnt']
  s.require_paths = ['lib']
end
