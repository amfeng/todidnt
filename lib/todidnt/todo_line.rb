class GitCommand
  def initialize(command, options)
    @command = command
    @options = options
  end

  def output_lines
    run!.strip.split(/\n/)
  end

  def run!
    `git #{command_with_options}`
  end

  def command_with_options
    full_command = @command.to_s

    for option in @options
      full_command << " #{option.join(' ')}"
    end

    full_command
  end
end

class TodoLine
  IGNORE = %r{assets/js|third_?party|node_modules|jquery|Binary}

  attr_reader :filename, :line_number, :content, :author

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

  def populate_blame
    line = `git blame --line-porcelain -L #{@line_number},#{@line_number} #{@filename}`
    if (author = /author (.*)/.match(line)) && (author_time = /author-time (.*)/.match(line))
      @author = author[1]
      @timestamp = author_time[1].to_i
    end
  end

  def pretty_time
    Time.at(@timestamp).strftime('%F')
  end

  def pretty
    "#{pretty_time} (#{author}, #{filename}:#{line_number}): #{content}"
  end
end

