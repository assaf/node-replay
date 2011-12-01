# NOTES:
# All requests using a hostname are routed to 127.0.0.1
# Port 3001 has a live server, see below for paths and responses
# Port 3002 has no server, connections will be refused


DNS = require("dns")
Express = require("express")
Replay = require("../lib/replay")


# Directory to load fixtures from.
Replay.fixtures = "#{__dirname}/fixtures"


# Redirect all HTTP requests to localhost
DNS.lookup = (domain, callback)->
  callback null, "127.0.0.1", 4

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


# Setup environment for running tests.
setup = (callback)->
  server.listen 3001, callback
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
exports.vows   = require("vows")
exports.HTTP   = require("http")
exports.Replay = Replay
