require "bunny"

vhost = ARGV[0]
user = ARGV[1]
password = ARGV[2]
exchange = ARGV[3]

conn =  Bunny.new(:host => "localhost", :vhost => vhost, :user => user, :password => password)
conn.start

ch1   = conn.create_channel
exchange    = ch1.fanout(exchange)

exchange.publish("some data")
