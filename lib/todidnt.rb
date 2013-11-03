require_relative 'todidnt/git_repo'
require_relative 'todidnt/git_command'
require_relative 'todidnt/todo_line'

class ToDidnt
  def initialize(path='.')
    @repo = GitRepo.new(path)
  end


  def run
    @repo.run do
      puts "Running in directory #{@working_dir}..."
      lines = TodoLine.all(["ach-in"])
      puts "Found #{lines.count} TODOs. Blaming..."

      count = 0
      lines.each do |todo|
        todo.populate_blame
        STDOUT.write "\rBlamed: #{count}/#{lines.count}"
        count += 1
      end

      puts
      puts "Results:"
      lines.each do |line|
        puts line.pretty
      end
    end
  end
end

#todidnt = ToDidnt.new('~/Stripe/pay-server')
#todidnt.run
