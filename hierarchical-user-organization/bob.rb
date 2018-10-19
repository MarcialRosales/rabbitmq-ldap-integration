require "bunny"

def pressKeyToTerminate
  print "Press any key to terminate\n"
  gets
end
def waitBeforeTerminate
  sleep(5)
end

conn =  Bunny.new(:host => "localhost", :vhost => "/", :user => "bob@example.com", :password => "password")
conn.start
print "Connected !! \n"

pressKeyToTerminate
