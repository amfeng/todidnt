module Todidnt
  class TodoLine
    IGNORE = %r{assets/js|third_?party|node_modules|jquery|Binary|vendor}

    attr_reader :filename, :line_number, :raw_content
    attr_accessor :author, :timestamp

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
