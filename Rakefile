task :test do
  $LOAD_PATH << './test'
  Dir.glob('test/test_*.rb').each { |t| require File.basename(t) }
end
