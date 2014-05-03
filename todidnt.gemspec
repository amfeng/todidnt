Gem::Specification.new do |s|
  s.name        = 'todidnt'
  s.version     = '0.2.0'
  s.summary     = 'Todidnt'
  s.description = "Todidnt finds and dates todos in your git repository."
  s.authors     = ["Amber Feng"]
  s.email       = 'amber.feng@gmail.com'

  s.add_development_dependency('minitest')
  s.add_development_dependency('mocha')

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- test/test_*.rb`.split("\n")
  s.executables   = ['todidnt']
  s.require_paths = ['lib']
end
