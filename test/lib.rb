unless defined? Todidnt
  $LOAD_PATH << File.expand_path('../../lib', __FILE__)
  require 'todidnt'
end

require 'minitest/spec'
require 'minitest/autorun'
require 'mocha/setup'

class Test < MiniTest::Spec
end
