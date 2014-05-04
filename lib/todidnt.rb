require 'todidnt/git_repo'
require 'todidnt/git_command'
require 'todidnt/todo_line'
require 'todidnt/git_history'
require 'todidnt/html_generator'

require 'chronic'
require 'launchy'

module Todidnt
  class CLI
    VALID_COMMANDS = %w{all overdue history}

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
      all_lines = self.all_lines(options).sort_by(&:timestamp)

      puts "\nOpening results..."

      file_path = HTMLGenerator.generate(:all, :all_lines => all_lines)
      Launchy.open("file://#{file_path}")
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
        buckets, authors = GitHistory.new.timeline!

        file_path = HTMLGenerator.generate(:history, :data => {:history => buckets.map {|h| h[:authors].merge('Date' => h[:timestamp]) }, :authors => authors.to_a})
        Launchy.open("file://#{file_path}")
      end
    end
  end
end
