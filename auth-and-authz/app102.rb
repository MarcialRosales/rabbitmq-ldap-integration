require "bunny"

def pressKeyToTerminate
  print "Press any key to terminate\r"
  gets
end

def waitBeforeTerminate
  sleep(5)
end

conn =  Bunny.new(:host => "localhost", :vhost => "dev", :user => "app102", :password => "password")
conn.start

ch1   = conn.create_channel
x_confirmations    = ch1.fanout("app102-x-confirmations")

while !conn.exchange_exists?("app101-x-requests")
  puts "app102: Wait until app101-x-requests is declared"
  sleep(2)
end

ch2   = conn.create_channel
x_requests    = ch1.fanout("app101-x-requests", :passive => true)
q_requests    = ch2.queue("app102-q-requests", :exclusive => true)
q_requests.bind(x_requests)
q_requests.subscribe() do |payload|
    puts "app102: ----> Received request "
    puts "app102: ----> Sending confirmation "
    x_confirmations.publish("some data")
end

waitBeforeTerminate
