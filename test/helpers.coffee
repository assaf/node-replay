# NOTES:
# All requests using a hostname are routed to 127.0.0.1
# Port 3001 has a live server, see below for paths and responses
# Port 3002 has no server, connections will be refused
# Port 3443 has a live https server


DNS     = require("dns")
Express = require("express")
Replay  = require("../lib/replay")
File    = require("fs")
Async   = require("async")


# Directory to load fixtures from.
Replay.fixtures = "#{__dirname}/fixtures"


# Redirect HTTP requests to pass-through domain
original_lookup = DNS.lookup
DNS.lookup = (domain, callback)->
  if domain == "pass-through"
    callback null, "127.0.0.1", 4
  else
    original_lookup domain, callback


# Serve pages from localhost.
server = Express.createServer()
server.use Express.bodyParser()
# Success page.
server.get "/", (req, res)->
  res.send "Success!"
# Not found
server.get "/404", (req, res)->
  res.send 404, "Not found"
# Internal error
server.get "/500", (req, res)->
  res.send 500, "Boom!"


# SSL Server
ssl_server = Express.createServer(
  key:  File.readFileSync("#{__dirname}/ssl/privatekey.pem")
  cert: File.readFileSync("#{__dirname}/ssl/certificate.pem")
)
ssl_server.use Express.bodyParser()
# Success page.
ssl_server.get "/", (req, res)->
  res.send "Success!"
# Not found
ssl_server.get "/404", (req, res)->
  res.send 404, "Not found"
# Internal error
ssl_server.get "/500", (req, res)->
  res.send 500, "Boom!"


# Setup environment for running tests.
setup = (callback)->
  Async.parallel [
    (done)->
      server.listen 3001, done
    (done)->
      ssl_server.listen 3443, done
  ], callback
    
  return

  if server._connected
    callback null
    return
  server.on "listening", callback
  unless server._connecting
    server._connecting = true
    server.listen 3001, ->
      server._connected = true


exports.assert = require("assert")
exports.setup  = setup
exports.HTTP   = require("http")
exports.HTTPS  = require("https")
exports.Replay = Replay
