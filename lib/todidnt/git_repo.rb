module ToDidnt
  class GitRepo
    def initialize(path)
      expanded_path = File.expand_path(path)

      if File.exist?(File.join(expanded_path, '.git'))
        @working_dir = expanded_path
      else
        raise "Whoops, #{expanded_path} is not a git repository!"
      end
    end

    def run(&blk)
      unless Dir.pwd == @working_dir
        Dir.chdir(@working_dir) do
          yield
        end
      else
        yield
      end
    end
  end
end
