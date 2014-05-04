require 'todidnt/cache'
require 'todidnt/git_repo'
require 'todidnt/git_command'
require 'todidnt/todo_line'
require 'todidnt/git_history'
require 'todidnt/html_generator'

require 'chronic'
require 'launchy'

module Todidnt
  class CLI
    VALID_COMMANDS = %w{generate clear}

    def self.run(command, options)
      command ||= 'generate'

      if command && VALID_COMMANDS.include?(command)
        self.send(command, options)
      elsif command
        $stderr.puts("Sorry, `#{command}` is not a valid command.")
        exit
      end
    end

    def self.generate(options)
      GitRepo.new(options[:path]).run do |path|
        history = GitHistory.new
        buckets, authors = history.timeline!

        lines = TodoLine.all(["TODO"])
        lines.each do |todo|
          blames = history.blames[todo.raw_content]

          if blames && (metadata = blames.pop)
            todo.author = metadata[:name]
            todo.timestamp = metadata[:time]
          else
            todo.author = "(Not yet committed)"
            todo.timestamp = Time.now.to_i
          end
        end

        file_path = HTMLGenerator.generate(:all, :all_lines => lines.sort_by(&:timestamp).reverse)
        file_path = HTMLGenerator.generate(:history, :data => {:history => buckets.map {|h| h[:authors].merge('Date' => h[:timestamp]) }, :authors => authors.to_a})
        Launchy.open("file://#{file_path}")
      end
    end

    def self.clear(options)
      Cache.clear!
    end
  end
end
