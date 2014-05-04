module Todidnt
  class GitHistory

    attr_accessor :blames

    def initialize
      @history = []
      @blames = {}
      @unmatched_deletions = []

      @command = GitCommand.new(:log, [['-G', 'TODO'], ['--format="COMMIT %an %ae %at %h"'], ['-p'], ['-U0'], ['--no-merges'], ['--reverse']])
    end

    def timeline!
      analyze
      bucket
    end

    private

    def analyze
      puts "Going through history..."

      patch_additions = []
      patch_deletions = []
      metadata = nil
      commit = nil
      seen_commits = Set.new
      count = 0

      @command.execute! do |line|
        if (diff = /diff --git a\/(.*) b\/(.*)/.match(line))
          filename = diff[1]
        elsif (diff = /^\+(.*TODO.*)/.match(line))
          patch_additions << diff[1]
        elsif (diff = /^\-(.*TODO.*)/.match(line))
          patch_deletions << diff[1]
        elsif (summary = /^COMMIT (.*) (.*) (.*) (.*)/.match(line))
          count += 1
          $stdout.write "\r#{count} commits analyzed..."

          unless commit.nil? || seen_commits.include?(commit) || filename =~ TodoLine::IGNORE
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

      flush(metadata, patch_additions, patch_deletions)

      puts
      if @unmatched_deletions.length > 0
        puts "Warning: there are some unmatched TODO deletions."
      end
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

      puts "Finalizing timeline..."
      buckets = []
      current_bucket_authors = {}
      bucket_total = 0

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

      [buckets, authors]
    end

  end
end
