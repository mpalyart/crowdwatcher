require 'twitter'
require 'json'
require 'mysql2'
require 'open-uri'
require 'icalendar'

OpenSSL::SSL::VERIFY_PEER = OpenSSL::SSL::VERIFY_NONE

gconf = JSON.parse(File.read("#{__dir__}/config.ini"))

# Check Public Google Calendar to see if there is a shift currently
aviary_calendar = Icalendar::Calendar.parse(open(gconf['GoogleCalendarICS']).read).first

current_shift = aviary_calendar.events.detect { |event| event.dtstart.value < DateTime.now && DateTime.now < event.dtend.value }

unless current_shift.nil?
  # Init connection to Twitter API 
  client = Twitter::REST::Client.new do |config|
    config.consumer_key        = gconf['TwitterAccount']['CONSUMER_KEY']
    config.consumer_secret     = gconf['TwitterAccount']['CONSUMER_SECRET']
    config.access_token        = gconf['TwitterAccount']['ACCESS_TOKEN']
    config.access_token_secret = gconf['TwitterAccount']['ACCESS_TOKEN_SECRET']
  end

  # Init connection to MySQL database 
  db_client = Mysql2::Client.new(:host => gconf['Database']['HOST'], :username =>  gconf['Database']['USER'], :password => gconf['Database']['PWD'], :database => gconf['Database']['NAME'])

  # last 15 minutes, last 30 minutes, Estimated people climbing
  nbLastCheckinsShortInterval = db_client.query("SELECT CUSTOMER_ID FROM checkins WHERE POSTDATE > date_sub(now(), interval #{gconf['LastCheckinsShortIntervalTime']} minute)").size
  nbLastCheckinsLongInterval = db_client.query("SELECT CUSTOMER_ID FROM checkins WHERE POSTDATE > date_sub(now(), interval #{gconf['LastCheckinsLongIntervalTime']} minute)").size
  estimatedNumberClimbers = db_client.query("SELECT CUSTOMER_ID FROM checkins WHERE POSTDATE > date_sub(now(), interval #{gconf['AvgClimbingSessionDuration']} minute)").size

  unless estimatedNumberClimbers == 0
    puts "Climbers arrived in the last #{gconf['LastCheckinsShortIntervalTime']} mins: #{nbLastCheckinsShortInterval},
                                  last #{gconf['LastCheckinsLongIntervalTime']} mins: #{nbLastCheckinsLongInterval}.
                                  Estimation total: #{estimatedNumberClimbers}"

    client.update("Climbers arrived in the last #{gconf['LastCheckinsShortIntervalTime']} mins: #{nbLastCheckinsShortInterval}, last #{gconf['LastCheckinsLongIntervalTime']} mins: #{nbLastCheckinsLongInterval}. Estimated total:  #{estimatedNumberClimbers}")
  end
else
  puts "Gym closed"
end
