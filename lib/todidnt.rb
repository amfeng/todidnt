require_relative 'todidnt/git_repo'
require_relative 'todidnt/git_command'
require_relative 'todidnt/todo_line'

module Todidnt
  class Runner
    def self.start(options)
      GitRepo.new(options[:path]).run do |path|
        puts "Running in #{path || 'current directory'}..."
        lines = TodoLine.all(["TODO"])
        puts "Found #{lines.count} TODOs. Blaming..."

        lines.each_with_index do |todo, i|
          todo.populate_blame
          $stdout.write "\rBlamed: #{i}/#{lines.count}"
        end

        puts "\nResults:"
        lines.each do |line|
          puts line.pretty
        end
      end
    end
  end
end
