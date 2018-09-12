require "bunny"

def pressKeyToTerminate
  print "Press any key to terminate\r"
  gets
end
def waitBeforeTerminate
  sleep(5)
end


conn =  Bunny.new(:host => "localhost", :vhost => "dev", :user => "app100", :password => "password")
conn.start

ch1   = conn.create_channel
x_events    = ch1.fanout("app100-x-events")

ch2   = conn.create_channel

while !conn.exchange_exists?("app102-x-confirmations")
  puts "app100: Wait until app102-x-confirmations is declared"
  sleep(2)
end
q_confirmations    = ch2.queue("app100-q-confirmations", :exclusive => true)
x_confirmations    = ch2.fanout("app102-x-confirmations", :passive => true)
q_confirmations.bind(x_confirmations)
q_confirmations.subscribe() do |payload|
    puts "app100: --> Received confirmation "
end

puts "app100: ---> Sending event "
x_events.publish("some data")

waitBeforeTerminate
