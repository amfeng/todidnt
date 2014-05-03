module Todidnt
  class TodoLine
    IGNORE = %r{assets/js|third_?party|node_modules|jquery|Binary|vendor}

    attr_reader :filename, :line_number, :content, :author, :timestamp

    def self.all(expressions)
      options = [['-n']]
      expressions.each { |e| options << ['-e', e] }

      grep = GitCommand.new(:grep, options)
      grep.output_lines.map do |line|
        filename, line_number, content = line.split(/:/, 3)
        unless filename =~ IGNORE
          lines = self.new(filename, line_number.to_i, content.strip[0..100])
        end
      end.compact
    end

    def initialize(filename, line_number, content)
      @filename = filename
      @line_number = line_number
      @content = content
    end

    # TODO: This logic should probably be moved out somewhere else
    def populate_blame
      options = [
        ['--line-porcelain'],
        ['-L', "#{@line_number},#{@line_number}"],
        ['-w'],
        [@filename]
      ]

      blame = GitCommand.new(:blame, options)
      blame.output_lines.each do |line|
        if (author = /author (.*)/.match(line))
          @author = author[1]
        elsif (author_time = /author-time (.*)/.match(line))
          @timestamp = author_time[1].to_i
        end
      end
    end

    def pretty_time
      Time.at(@timestamp).strftime('%F')
    end

    def pretty
      "#{pretty_time} (#{author}, #{filename}:#{line_number}): #{content}"
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
