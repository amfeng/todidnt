require 'subprocess'

module Todidnt
  class GitCommand
    def initialize(command, options)
      @command = command
      @options = options

      @process = Subprocess::Process.new(command_with_options, :stdout => Subprocess::PIPE)
    end

    def execute!(&blk)
      @process.stdout.each_line do |line|
        yield line.chomp
      end
    end

    def command_with_options
      full_command = @command.to_s

      for option in @options
        full_command << " #{option.join(' ')}"
      end

      "git #{full_command}"
    end
  end
end
