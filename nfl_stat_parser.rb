require 'nokogiri'
require 'open-uri'

class NFLStatParser
  attr_reader :stats_by_year
  
  # When creating an instance, pass in the year or range of years you want to analyze.
  def initialize(range = 2010)
    @cached_raw_stats = Hash.new()
    @stats_by_year = {}
    @year_range = range.is_a?(Range) ? range : (range..range)
  end
  
  # Get the webpage for the specified season and parse it with Nokogiri.
  def get_stats(season)
    return @cached_raw_stats[season] unless @cached_raw_stats[season].nil?
    
    season_stats = nil
    begin
      season_stats = Nokogiri::HTML(open("http://www.nfl.com/standings?category=league&season=#{season}-REG&split=Overall"))
      puts "Read stats for #{season}"
    rescue EOFError => e
      puts "Couldn't read #{season}"
    end
    
    @cached_raw_stats[season] = season_stats
  end
  
  # Grab the team name and record fields from the HTML page.
  def parse_stats(range = @year_range)
    range.each do |season|
      stats = nil
      attempts = 0
      while stats.nil? && attempts < 3 
        attempts += 1
        stats = get_stats(season)
      end
      # If for some reason we weren't able to read the specified page skip to the following season
      next if attempts == 3
      
      headers = stats.css('tr.thd2').css('td a').collect { |node| node.text}
      win_index = headers.index('W').to_i + 1
      # The table that has all of the stats has the stats in rows with a class of tbdy1
      stats_by_team = stats.css('tr.tbdy1').each do |team_row|
        # The team name is surrounded by tabs and other characters, so it has to be cleaned up
        team_name = team_row.css('td a, td').text.match(/([\w\.\- ]+)/)[0]
        wins, losses, ties = team_row.css('td')[win_index..(win_index + 2)].collect { |data| data.text.to_i }
        
        # Group stats by season...
        @stats_by_year[season] ||= {}
        # Then by team name. Note: this does not reconcile teams that have moved with their current team names/locations.
        @stats_by_year[season][team_name] = { :wins => wins, :losses => losses, :ties => ties }
      end
    end
    
    @stats_by_year
  end
  
  # Sums up wins, losses and ties for the year range that was initially passed in.
  # e.g. To get all of the wins/losses/ties for a team during the free agency period:
  # NFLStatParser.new(1993..2010).sum_wins_losses #=> [["New England Patriots", {:wins=>180, :losses=>103, :ties=>0}], ...]
  def sum_wins_losses
    self.parse_stats if @stats_by_year.empty?
    
    team_records = {}
    @stats_by_year.inject({}) do |sum_by_team, season_and_teams|
      _, teams = season_and_teams
      
      teams.each do |team_name, record|
        record.each do |record_type, number|
          team_records[team_name] ||= {}
          record_sum = team_records[team_name][record_type].to_i
          begin
            team_records[team_name][record_type] = record_sum + number
          rescue
            raise number.inspect
          end
        end
      end
    end
    
    return team_records
  end
end
