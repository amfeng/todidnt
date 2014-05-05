require 'tilt'
require 'erb'
require 'fileutils'
require 'json'

module Todidnt
  class Cache
    CACHE_PATH = '.todidnt/cache'

    attr_reader :time, :data

    def initialize(data)
      @time = Time.now.to_i
      @data = data
    end

    def self.save(key, data)
      Dir.mkdir(CACHE_PATH) unless Dir.exists?(CACHE_PATH)

      File.open("#{CACHE_PATH}/#{key}", 'w') do |file|
        file.write(Marshal.dump(Cache.new(data)))
      end

    end

    def self.load(key)
      return nil unless exists?(key)

      begin
        raw_cache = File.open("#{CACHE_PATH}/#{key}").read
        Marshal.load(raw_cache)
      rescue Exception
        puts "Cache file was malformed; skipping..."
        nil
      end
    end

    def self.exists?(key)
      File.exists?("#{CACHE_PATH}/#{key}")
    end

    def self.clear!
      Dir.glob("#{CACHE_PATH}/*").each do |file|
        File.delete(file)
      end
    end
  end
end
