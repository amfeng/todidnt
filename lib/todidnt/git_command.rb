module Todidnt
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
end
