module Todidnt
  class GitHistory

    attr_accessor :blames

    def initialize(opts)
      @history = []
      @blames = {}
      @unmatched_deletions = []

      # Contributor threshold (e.g. only show as a separate contributor
      # if they've contributed to > N% of TODOs).
      @threshold = opts[:threshold]
    end

    def timeline!
      # TODO: It would probably be better/simpler to just Marshal the
      # GitHistory object itself.
      if Cache.exists?(:history)
        puts "Found cached history..."

        cache = Cache.load(:history)

        @history = cache.data[:history]
        @blames = cache.data[:blames]
        @unmatched_deletions = cache.data[:unmatched_deletions]

        last_commit = cache.data[:last_commit]
      end

      new_commit = analyze(last_commit)
      if new_commit != last_commit
        # If there's any new history, update the cache.
        to_cache = {
          last_commit: new_commit,
          history: @history,
          blames: @blames,
          unmatched_deletions: @unmatched_deletions
        }

        Cache.save(:history, to_cache)
      end

      if @unmatched_deletions.length > 0
        puts "Warning: there are some unmatched TODO deletions."
      end

      bucket
    end

    private

    def analyze(last_commit=nil)
      if last_commit
        puts "Going through history starting at #{last_commit}..."
        commit_range = ["#{last_commit}...HEAD"]
      else
        puts "Going through history..."
      end

      command = GitCommand.new(:log, [['-G', 'TODO'], commit_range, ['--format="COMMIT %an %ae %at %h"'], ['-p'], ['-U0'], ['--no-merges'], ['--reverse']].compact)

      patch_additions = []
      patch_deletions = []
      metadata = nil
      filename = nil
      commit = nil
      seen_commits = Set.new
      count = 0

      command.execute! do |line|
        line.encode!('UTF-8', 'binary', invalid: :replace, undef: :replace, replace: '')

        if (diff = /diff --git a\/(.*) b\/(.*)/.match(line))
          filename = diff[1]
        elsif (diff = /^\+(.*TODO.*)/.match(line))
          patch_additions << diff[1] unless filename =~ TodoLine::IGNORE
        elsif (diff = /^\-(.*TODO.*)/.match(line))
          patch_deletions << diff[1] unless filename =~ TodoLine::IGNORE
        elsif (summary = /^COMMIT (.*) (.*) (.*) (.*)/.match(line))
          count += 1
          $stdout.write "\r#{count} commits analyzed..."

          unless commit.nil? || seen_commits.include?(commit)
            flush(metadata, patch_additions, patch_deletions)
            seen_commits << commit
          end

          patch_additions = []
          patch_deletions = []

          commit = summary[4]
          metadata = {
            name: summary[1],
            time: summary[3].to_i,
          }
        end
      end

      if commit
        puts
        flush(metadata, patch_additions, patch_deletions)
      end

      return commit || last_commit # return the last commit hash we were on
    end

    def flush(metadata, patch_additions, patch_deletions)
      name = metadata[:name]
      time = metadata[:time]

      # Put the additions in the blame hash so when someone removes we
      # can tell who the original author was. Mrrrh, this isn't going to
      # work if people add the same string (pretty common e.g. # TODO).
      # We can figure this out later thoug.
      patch_additions.each do |line|
        @blames[line] ||= []
        @blames[line] << {name: name, time: time}
      end

      deletions_by_author = {}
      patch_deletions.each do |line|
        author = @blames[line] && @blames[line].pop

        if author
          deletions_by_author[author[:name]] ||= 0
          deletions_by_author[author[:name]] += 1
        else
          @unmatched_deletions << line
        end
      end

      @history << {
        :timestamp => time,
        :author => name,
        :additions => patch_additions.count,
        :deletions => deletions_by_author[name] || 0
      }

      deletions_by_author.delete(name)
      deletions_by_author.each do |author, deletion_count|
        @history << {
          :timestamp => time,
          :author => author,
          :additions => 0,
          :deletions => deletion_count
        }
      end
    end

    def bucket
      @history.sort_by! {|slice| slice[:timestamp]}
      min_commit_date = Time.at(@history.first[:timestamp])
      max_commit_date = Time.at(@history.last[:timestamp])

      timespan = max_commit_date - min_commit_date

      # Figure out what the interval should be based on the total timespan.
      if timespan > 86400 * 365 * 10 # 10+ years
        interval = 86400 * 365 # years
        timespan_label = 'years'
      elsif timespan > 86400 * 365 * 5 # 5-10 years
        interval = 86400 * (365 / 2) # 6 months
        timespan_label = 'months'
      elsif timespan > 86400 * 365 # 2-5 years
        interval = 86400 * (365 / 4) # 3 months
        timespan_label = 'months'
      elsif timespan > 86400 * 30 * 6 # 6 months-3 year
        interval = 86400 * 30 # months
        timespan_label = 'months'
      elsif timespan > 86400 * 14 * 1 # 1/2 month - 6 months
        interval = 86400 * 7
        timespan_label = 'days'
      else # 0 - 1/2 months
        interval = 86400 # days
        timespan_label = 'days'
      end

      original_interval_start = Time.new(min_commit_date.year, min_commit_date.month, min_commit_date.day).to_i
      interval_start = original_interval_start
      interval_end = interval_start + interval

      puts "Finalizing timeline..."
      buckets = []
      current_bucket_authors = {}
      bucket_total = 0

      # Add the first bucket of 0
      buckets << {
        :timestamp => format_date(Time.at(interval_start), timespan_label),
        :authors => {},
        :total => 0
      }

      i = 0
      # Going through the entire history of +/-'s of TODOs.
      while i < @history.length
        should_increment = false
        slice = @history[i]
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
        if i == (@history.length - 1) || @history[i + 1][:timestamp] >= interval_end
          buckets << {
            :timestamp => format_date(([Time.at(interval_end), max_commit_date].min), timespan_label),
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
          if count > bucket[:total] * @threshold
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

      [buckets, authors]
    end

    private

    def format_date(date, timespan_label)
      case timespan_label
      when 'years'
        date.strftime('%Y')
      when 'months'
        date.strftime('%-m/%y')
      when 'days'
        date.strftime('%-m/%-d')
      end
    end
  end
end
