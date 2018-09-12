require "bunny"

def pressKeyToTerminate
  print "Press any key to terminate\r"
  gets
end
def waitBeforeTerminate
  sleep(5)
end

vhost = ARGV[0]

conn =  Bunny.new(:host => "localhost", :vhost => vhost, :user => "app100", :password => "password")
conn.start

pressKeyToTerminate
