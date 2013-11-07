require_relative 'todidnt/git_repo'
require_relative 'todidnt/git_command'
require_relative 'todidnt/todo_line'

module Todidnt
  class Runner
    def self.start(options)
      path = options[:path]
      GitRepo.new(path).run do
        puts "Running in #{path || 'current directory'}..."
        lines = TodoLine.all(["TODO"])
        puts "Found #{lines.count} TODOs. Blaming..."

        count = 0
        lines.each do |todo|
          todo.populate_blame
          count += 1
          STDOUT.write "\rBlamed: #{count}/#{lines.count}"
        end

        puts
        puts "Results:"
        lines.each do |line|
          puts line.pretty
        end
      end
    end
  end
end
