require 'tilt'
require 'erb'
require 'fileutils'
require 'json'

module Todidnt
  class Cache
    CACHE_PATH = '.todidnt/cache'

    def self.save(key, data)
      Dir.mkdir(CACHE_PATH) unless Dir.exists?(CACHE_PATH)

      File.open("#{CACHE_PATH}/#{key}", 'w') do |file|
        file.write(Marshal.dump(data))
      end

    end

    def self.load(key)
      return nil unless exists?(key)

      content = File.open("#{CACHE_PATH}/#{key}").read
      Marshal.load(content)
    end

    def self.exists?(key)
      File.exists?("#{CACHE_PATH}/#{key}")
    end

    def self.clear!
      # TODO
    end
  end
end
