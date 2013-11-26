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

        history_by_author = {}

        patch_additions = ''
        patch_deletions = ''
        log.output_lines.reverse.each do |line|
          if (summary = /^COMMIT (.*) (.*) (.*)/.match(line))
            name = summary[1]
            email = summary[2]
            time = summary[3]

            history_by_author[email] ||= []
            history_by_author[email] << [time.to_i, patch_additions.scan('TODO').count, patch_deletions.scan('TODO').count]

            patch_additions = ''
            patch_deletions = ''
          elsif (diff = /^\+(.*)/.match(line))
            patch_additions << diff[1]
          elsif (diff = /^\-(.*)/.match(line))
            patch_deletions << diff[1]
          end
        end

        min_commit_date = Time.at(history_by_author.map {|author, history| history}[0].map(&:first).min)

        interval = 86400
        original_interval_start = Time.new(min_commit_date.year, min_commit_date.month, min_commit_date.day).to_i
        interval_start = original_interval_start
        interval_end = interval_start + interval

        history_by_author.each do |author, history|
          buckets = []
          current_total = 0
          interval_start = original_interval_start

          i = 0
          while i < history.length
            should_increment = false
            slice = history[i]

            # Does the current slice exist inside the bucket we're currently
            # in? If so, add it to the total, and go to the next slice.
            if slice[0] >= interval_start && slice[0] < interval_end
              current_total += (slice[1] - slice[2])
              should_increment = true
            end

            # If we're on the last slice, or the next slice would have been
            # in a new bucket, finish the current bucket.
            if i == (history.length - 1) || history[i + 1][0] >= interval_end
              buckets << [interval_start, current_total]
              interval_start += interval
              interval_end += interval
            end

            i += 1 if should_increment
          end

          history_by_author[author] = buckets
        end

        history_by_author.each do |author, history|
          puts "For #{author}:"

          history.each do |slice|
            print "#{Time.at(slice[0])} |"
            print "*"*([0, slice[1]].max)
            print " (#{slice[1]})"
            print "\n"
          end
        end
      end
    end
  end
end
