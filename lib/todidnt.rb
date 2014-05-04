require 'todidnt/git_repo'
require 'todidnt/git_command'
require 'todidnt/todo_line'
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
        log = GitCommand.new(:log, [['-G', 'TODO'], ['--format="COMMIT %an %ae %at %h"'], ['-m'], ['-p'], ['--cc'], ['-U0'], ['--reverse']])

        history = []

        blame_hash = {}

        puts "Going through log..."
        patch_additions = []
        patch_deletions = []
        filename = nil
        seen_commits = Set.new
        count = 0

        # Log entries of the format:
        #
        # diff --git a/<FILENAME> b/<FILENAME>
        # index <COMMIT>..<COMMIT>
        # --- a/<FILENAME>
        # +++ b/<FILENAME>
        # <DIFF>
        # COMMIT <NAME> <EMAIL> <DATE>

        log.execute! do |line|
          if (diff = /diff --git a\/(.*) b\/(.*)/.match(line))
            filename = diff[1]
          elsif (diff = /^\w*\++(.*TODO.*)/.match(line))
            patch_additions << diff[1]
          elsif (diff = /^\w*\-+(.*TODO.*)/.match(line))
            patch_deletions << diff[1]
          elsif (summary = /^COMMIT (.*) (.*) (.*) (.*)/.match(line))
            count += 1
            $stdout.write "\r#{count} commits analyzed"

            name = summary[1]
            email = summary[2]
            time = summary[3]
            commit = summary[4]

            unless seen_commits.include?(commit) || filename =~ TodoLine::IGNORE
              # Put the additions in the blame hash so when someone removes we
              # can tell who the original author was. Mrrrh, this isn't going to
              # work if people add the same string (pretty common e.g. # TODO).
              # We can figure this out later thoug.
              patch_additions.each do |line|
                blame_hash[line] ||= []
                blame_hash[line] << name
              end

              deletions_by_author = {}
              patch_deletions.each do |line|
                author = blame_hash[line] && blame_hash[line].pop

                if author
                  deletions_by_author[author] ||= 0
                  deletions_by_author[author] += 1
                else
                  puts "BAD BAD can't find original author: #{line}"
                end
              end

              history << {
                :timestamp => time.to_i,
                :author => name,
                :additions => patch_additions.count,
                :deletions => deletions_by_author[name] || 0
              }

              deletions_by_author.delete(name)
              deletions_by_author.each do |author, deletion_count|
                history << {
                  :timestamp => time.to_i,
                  :author => author,
                  :additions => 0,
                  :deletions => deletion_count
                }
              end
            end

            patch_additions = []
            patch_deletions = []

            seen_commits << commit
          end
        end

        history.sort_by! {|slice| slice[:timestamp]}
        min_commit_date = Time.at(history.first[:timestamp])
        max_commit_date = Time.at(history.last[:timestamp])

        timespan = max_commit_date - min_commit_date

        # Figure out what the interval should be based on the total timespan.
        if timespan > 86400 * 365 * 10 # 10+ years
          interval = 86400 * 365 # years
        elsif timespan > 86400 * 365 * 5 # 5-10 years
          interval = 86400 * (365 / 2) # 6 months
        elsif timespan > 86400 * 365 # 2-5 years
          interval = 86400 * (365 / 4) # 3 months
        elsif timespan > 86400 * 30 * 6 # 6 months-3 year
          interval = 86400 * 30 # months
        elsif timespan > 86400 * 1 # 1 month - 6 months
          interval = 86400 * 7
        else # 0 - 2 months
          interval = 86400 # days
        end

        original_interval_start = Time.new(min_commit_date.year, min_commit_date.month, min_commit_date.day).to_i
        interval_start = original_interval_start
        interval_end = interval_start + interval

        puts "\nFinalizing timeline..."
        buckets = []
        current_bucket_authors = {}
        bucket_total = 0

        i = 0
        # Going through the entire history of +/-'s of TODOs.
        while i < history.length
          should_increment = false
          slice = history[i]
          author = slice[:author]

          # Does the current slice exist inside the bucket we're currently
          # in? If so, add it to the author's total and go to the next slice.
          if slice[:timestamp] >= interval_start && slice[:timestamp] < interval_end
            current_bucket_authors[author] ||= 0
            current_bucket_authors[author] += slice[:additions] - slice[:deletions]
            bucket_total += slice[:additions] - slice[:deletions]
            should_increment = true
          end

          # If we're on the last slice, or the next slice would have been
          # in a new bucket, finish the current bucket.
          if i == (history.length - 1) || history[i + 1][:timestamp] >= interval_end
            buckets << {
              :timestamp => Time.at(interval_start).strftime('%D'),
              :authors => current_bucket_authors,
              :total => bucket_total
            }
            interval_start += interval
            interval_end += interval

            current_bucket_authors = current_bucket_authors.clone
          end

          i += 1 if should_increment
        end

        authors = Set.new
        contains_other = false
        buckets.each do |bucket|
          significant_authors = {}
          other_count = 0
          bucket[:authors].each do |author, count|
            # Only include the author if they account for more than > 3% of
            # the TODOs in this bucket.
            if count > bucket[:total] * 0.03
              significant_authors[author] = count
              authors << author
            else
              other_count += count
            end
          end

          if other_count > 0
            significant_authors['Other'] = other_count
            contains_other = true
          end

          bucket[:authors] = significant_authors
        end

        if contains_other
          authors << 'Other'
        end

        file_path = HTMLGenerator.generate(:history, :data => {:history => buckets.map {|h| h[:authors].merge('Date' => h[:timestamp]) }, :authors => authors.to_a})
        Launchy.open("file://#{file_path}")
      end
    end
  end
end
