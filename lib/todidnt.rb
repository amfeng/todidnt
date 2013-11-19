require 'todidnt/git_repo'
require 'todidnt/git_command'
require 'todidnt/todo_line'

require 'chronic'

module Todidnt
  class CLI
    VALID_COMMANDS = %w{all overdue}

    def self.run(command, options)
      if command && VALID_COMMANDS.include?(command)
        self.send(command, options)
      elsif command
        $stderr.puts("Sorry, `#{command}` is not a valid command.")
        exit
      else
        $stderr.puts("You must specify a command! Try `todidnt all`.")
      end
    end

    def self.all(options)
      all_lines = self.all_lines(options)

      puts "\nResults:"
      all_lines.sort_by do |line|
        line.timestamp
      end.each do |line|
        puts line.pretty
      end
    end

    def self.overdue(options)
      date = Chronic.parse(options[:date] || 'now', :context => :past)
      if date.nil?
        $stderr.puts("Invalid date passed: #{options[:date]}")
        exit
      else
        puts "Finding overdue TODOs (created before #{date.strftime('%F')})..."
      end

      all_lines = self.all_lines(options)

      puts "\nResults:"
      all_lines.sort_by do |line|
        line.timestamp
      end.select do |line|
        line.timestamp < date.to_i
      end.each do |line|
        puts line.pretty
      end
    end

    def self.all_lines(options)
      GitRepo.new(options[:path]).run do |path|
        puts "Running in #{path || 'current directory'}..."
        lines = TodoLine.all(["TODO"])
        puts "Found #{lines.count} TODOs. Blaming..."

        lines.each_with_index do |todo, i|
          todo.populate_blame
          $stdout.write "\rBlamed: #{i}/#{lines.count}"
        end

        lines
      end
    end

    def self.history(options)
      GitRepo.new(options[:path]).run do |path|
        log = GitCommand.new(:log, [['-G', 'TODO'], ['--format="COMMIT %an %ae %at"'], ['-p'], ['-U0']])

        todos = {}

        name, email, time = nil
        patch_additions = nil
        patch_deletions = nil
        next_deletions = []
        log.output_lines.each do |line|
          if (summary = /COMMIT (.*) (.*) (.*)/.match(line))
            if email
              todos[email] << [time, patch_additions.scan('TODO').count, patch_deletions.scan('TODO').count]
            end

            # We're on a new commit now
            name = summary[1]
            email = summary[2]
            time = summary[3]

            todos[email] ||= []
            patch_additions = ''
            patch_deletions = ''
          elsif (diff = /^\+(.*)/.match(line))
            patch_additions << diff[1]
          elsif (diff = /^\-(.*)/.match(line))
            patch_deletions << diff[1]
          end
        end
        todos[email] << [time, patch_additions.scan('TODO').count, patch_deletions.scan('TODO').count]

        puts todos.inspect
      end
    end
  end
end
