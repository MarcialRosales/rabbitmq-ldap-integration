require "bunny"

def pressKeyToTerminate
  print "Press any key to terminate\r"
  gets
end

def waitBeforeTerminate
  sleep(5)
end

conn =  Bunny.new(:host => "localhost", :vhost => "dev", :user => "app101", :password => "password")
conn.start

ch1   = conn.create_channel
x_requests    = ch1.fanout("app101-x-requests")

ch2   = conn.create_channel
q_events    = ch2.queue("app101-q-events", :exclusive => true)

while !conn.exchange_exists?("app100-x-events")
  puts "app101: Wait until app100-x-events is declared"
  sleep(2)
end

x_events    = ch2.fanout("app100-x-events", :passive => true)
q_events.bind(x_events)
q_events.subscribe() do |payload|
    puts "app101: -----> Received event "
    puts "app101: -----> Sending request"
    x_requests.publish("some data")
end

waitBeforeTerminate
