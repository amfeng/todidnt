module Todidnt
  class TodoLine
    IGNORE = %r{assets/js|third_?party|node_modules|jquery|Binary|vendor}

    attr_reader :filename, :line_number, :raw_content
    attr_accessor :author, :timestamp

    def self.all(expressions)
      options = [['-n']]
      expressions.each { |e| options << ['-e', e] }

      lines = []

      command = GitCommand.new(:grep, options)
      command.execute! do |line|
        filename, line_number, content = line.split(/:/, 3)
        unless filename =~ IGNORE
          lines << self.new(filename, line_number.to_i, content)
        end
      end

      lines
    end

    def initialize(filename, line_number, raw_content)
      @filename = filename
      @line_number = line_number
      @raw_content = raw_content
    end

    def pretty_time
      Time.at(@timestamp).strftime('%F')
    end

    def content
      raw_content.strip[0..100]
    end

    def to_hash
      {
        :time => pretty_time,
        :author => author,
        :filename => filename,
        :line_number => line_number,
        :content => content
      }
    end
  end
end
