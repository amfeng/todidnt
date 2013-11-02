require_relative 'todidnt/todo_line'

class ToDidnt
  def initialize(path='.')
    expanded_path = File.expand_path(path)

    if File.exist?(File.join(expanded_path, '.git'))
      @working_dir = expanded_path
    else
      raise "Whoops, #{expanded_path} is not a git repository!"
    end
  end

  def run_in_working_directory(&blk)
    if Dir.getwd != @working_dir
      Dir.chdir(@working_dir) do
        yield
      end
    else
      yield
    end
  end

  def run
    run_in_working_directory do
      puts "Running in directory #{@working_dir}..."
      lines = TodoLine.all(["TODO"])
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

todidnt = ToDidnt.new('~/Stripe/pay-server')
todidnt.run
