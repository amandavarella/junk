# frozen_string_literal: true

$LOAD_PATH << File.join(File.expand_path(__dir__), 'lib')

require 'org_chart'
require 'bamboozled'
require 'active_support/core_ext/date'
require 'active_support/core_ext/integer'
require 'optparse'
require 'dotenv'
Dotenv.load

# rubocop:disable Metrics/MethodLength,Metrics/AbcSize
def parse!
  options = {}
  OptionParser.new do |opts|
    opts.banner = "Usage: #{$PROGRAM_NAME} [options]"

    opts.on('-u', '--under-user NAME', 'What user to generate report under') do |u|
      options[:under_user] = u
    end

    opts.on('-i', '--ignore NAME', 'People to ignore in the report') do |u|
      options[:ignore] = u.split(',')
    end

    opts.on('-s', '--start-date DATE', 'Start date of the week to report on') do |d|
      options[:start_date] = Date.parse(d).beginning_of_week
    end

    opts.on('-w', '--weeks NUMBER', 'Number of weeks to report on') do |n|
      options[:weeks] = n.to_i
    end

    opts.on('-t', '--transpose', 'Paste results transposed') do |n|
      options[:transposed] = true
    end

  end.parse!

  options[:start_date] ||= Date.today.beginning_of_week
  options[:finish_date] = options[:start_date] + 4
  options[:weeks] ||= 1

  unless options[:under_user]
    puts 'Missing argument --under-user'
    exit(1)
  end

  options
end
# rubocop:enable Metrics/MethodLength,Metrics/AbcSize

# Monkey patch bug in Skookum/bamboozled
class Array
  def with_indifferent_access
    self
  end
end

def reports(name, ignore: [])
  person = OrgChart.lookup(name).first
  memo = [ person ]
  OrgChart.reports(person).each do |report|
    next if !ignore.nil? && ignore.include?(report[:name])
    memo << reports(report[:name])
  end
  memo.flatten.uniq
end

def responsible_for?(reports:, person:)
  reports.any? { |r| r[:id] == person['employeeId'] }
end

# rubocop:disable Metrics/MethodLength,Metrics/AbcSize
def calculate_work_days(people:, leave:, timeframe:)
  work_days = {}
  timeframe_range = (timeframe.start..timeframe.finish).to_a

  people.each do |person|
    work_days[person[:name]] = 5
    time_off = leave.select { |e| e['employeeId'].to_s == person[:id] }

    time_off.each do |entry|
      leave_range = (Date.parse(entry['start'])..Date.parse(entry['end'])).to_a
      days_off = leave_range & timeframe_range
      work_days_off = days_off.reject { |d| d.saturday? || d.sunday? }
      work_days[person[:name]] -= work_days_off.size
    end
  end

  work_days
end
# rubocop:enable Metrics/MethodLength,Metrics/AbcSize

def deduct_holidays(work_days:, leave:)
  holidays = leave.select { |l| l['type'] == 'holiday' }
  holidays.each do
    work_days.each do |name, count|
      work_days[name] -= 1 unless count <= 0
    end
  end
  work_days
end

def print_totals(reports)
  header = (['date'] + reports.map { |t, r| t.start.to_s })
  puts header.join(",")

  totals = Hash[reports.first.last.keys.sort.map { |n| [ n, [] ] }]
  reports.map(&:last).each { |r| r.each { |name, count| totals[name] << count } }

  totals.each do |name, counts|
    puts ([ name ] + counts).join(",")
  end
end

def print_totals_transposed(reports)

  totals = Hash[reports.first.last.keys.sort.map { |n| [ n, [] ] }]
  names=totals.keys.join(",")
  header = ("date,"+ names)
  puts header

  dates=reports.map { |t, r| t.start.to_s }

  reports.map(&:last).each { |r| 
    r.each { |name, count| 
      totals[name] << count 
    } 
  }

  dates.each_with_index do |date,i|
    line=date
    totals.each do |name, counts|
      line+="," + counts[i].to_s
    end
    puts line
  end

end


# rubocop:disable Metrics/MethodLength,Metrics/AbcSize
def main
  # setup
  options = parse!
  params = {
    subdomain: ENV['BAMBOOHR_SUBDOMAIN'],
    api_key: ENV['BAMBOOHR_API_KEY']
  }
  client = Bamboozled.client(params)

  case
  when File.exist?('employees.json')
    OrgChart.engine = OrgChartEngine::JSON
    hash = JSON.parse(File.read('employees.json'))
  when File.exist?('employees.csv')
    OrgChart.engine = OrgChartEngine::CSV
    hash = CSV.read('employees.csv', headers: true).map(&:to_hash)
  else
    puts 'Unable to find org chart to read'
    exit(1)
  end

  OrgChart.from(hash)

  # get the people we need to produce a report for
  people = reports(options[:under_user], ignore: options[:ignore])

  # get the people we don't want in the report
  temp = open("remove_people.csv").read
  people_to_remove = temp.split(",")
  
  # remove the people we don't want in the report
  loop do
    person_to_remove = people_to_remove.shift
    people.each {|p| people.delete(p) if p[:name] == person_to_remove }
    break if people_to_remove.length==0
  end

  reports = []
  0.upto(options[:weeks] - 1) do |i|
    timeframe = OpenStruct.new(start: options[:start_date] + (i * 7), finish: options[:start_date] + (i * 7) + 4)

    all_leave = client.time_off.whos_out(timeframe.start, timeframe.finish)

    # calculate work days from leave
    work_days = calculate_work_days(people: people, leave: all_leave, timeframe: timeframe)

    # deduct holidays
    work_days = deduct_holidays(work_days: work_days, leave: all_leave)

    reports << [ timeframe, work_days ]
  end

  # print the totals
  case options[:transposed]
    when true
      print_totals_transposed(reports)
    else
      print_totals(reports)
  end

end
# rubocop:enable Metrics/MethodLength,Metrics/AbcSize

main if $PROGRAM_NAME == __FILE__
