require 'todidnt/git_repo'
require 'todidnt/git_command'
require 'todidnt/todo_line'

require 'chronic'
require 'erb'
require 'launchy'
require 'tilt'

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

      render_and_open_all(all_lines)
    end

    def self.render_and_open_all(all_lines)
      path_to = File.join(File.dirname(File.expand_path(__FILE__)), '../')
      content_template = Tilt::ERBTemplate.new(path_to + 'templates/all.erb')
      layout_template = Tilt::ERBTemplate.new(path_to + 'templates/layout.erb')

      content = content_template.render nil, :all_lines => all_lines
      result = layout_template.render { content }

      File.open('todidnt-all.html', 'w') do |file|
        file.write(result)
      end

      File.open('style.css', 'w') do |file|
        file.write(File.read(path_to + 'templates/style.css'))
      end

      Launchy.open("file://#{File.absolute_path('todidnt-all.html')}")
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

        puts "Going through log..."
        patch_additions = ''
        patch_deletions = ''
        total = log.output_lines.count
        log.output_lines.reverse.each do |line|
          if (summary = /^COMMIT (.*) (.*) (.*)/.match(line))
            name = summary[1]
            email = summary[2]
            time = summary[3]

            history_by_author[email] ||= []
            history_by_author[email] << {
              :timestamp => time.to_i,
              :additions => patch_additions.scan('TODO').count,
              :deletions => patch_deletions.scan('TODO').count
            }

            patch_additions = ''
            patch_deletions = ''
          elsif (diff = /^\+(.*)/.match(line))
            patch_additions << diff[1]
          elsif (diff = /^\-(.*)/.match(line))
            patch_deletions << diff[1]
          end
        end

        min_commit_date = Time.at(history_by_author.map {|author, history| history}.first.map {|d| d[:timestamp]}.min)

        interval = 86400
        original_interval_start = Time.new(min_commit_date.year, min_commit_date.month, min_commit_date.day).to_i
        interval_start = original_interval_start
        interval_end = interval_start + interval

        puts "Finalizing timeline..."
        history_by_author.each do |author, history|
          buckets = []
          current_total = 0
          interval_start = original_interval_start
          interval_end = interval_start + interval

          i = 0
          history = history.sort_by {|slice| slice[:timestamp]}
          while i < history.length
            should_increment = false
            slice = history[i]

            # Does the current slice exist inside the bucket we're currently
            # in? If so, add it to the total, and go to the next slice.
            if slice[:timestamp] >= interval_start && slice[:timestamp] < interval_end
              current_total += (slice[:additions] - slice[:deletions])
              should_increment = true
            end

            # If we're on the last slice, or the next slice would have been
            # in a new bucket, finish the current bucket.
            if i == (history.length - 1) || history[i + 1][:timestamp] >= interval_end
              buckets << {
                :timestamp => interval_start,
                :total => current_total
              }
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
            print "#{Time.at(slice[:timestamp])} |"
            print "*"*([0, slice[:total]].max / 10)
            print " (#{slice[:total]})"
            print "\n"
          end
        end
      end
    end
  end
end
