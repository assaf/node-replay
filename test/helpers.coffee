# NOTES:
# All requests using a hostname are routed to 127.0.0.1
# Port 3004 has a live server, see below for paths and responses
# Port 3002 has no server, connections will be refused
# Port 3443 has a live https server


DNS         = require("dns")
express     = require("express")
bodyParser  = require("body-parser")
HTTP        = require("http")
HTTPS       = require("https")
Replay      = require("../src/replay")
File        = require("fs")
Async       = require("async")


HTTP_PORT     = 3004
HTTPS_PORT    = 3443
INACTIVE_PORT = 3002
SSL =
  key:  File.readFileSync("#{__dirname}/ssl/privatekey.pem")
  cert: File.readFileSync("#{__dirname}/ssl/certificate.pem")


# Directory to load fixtures from.
Replay.fixtures = "#{__dirname}/fixtures"

Replay.silent = true


# Redirect HTTP requests to pass-through domain
original_lookup = DNS.lookup
DNS.lookup = (domain, callback)->
  if domain == "pass-through"
    callback null, "127.0.0.1", 4
  else
    original_lookup domain, callback


# Serve pages from localhost.
server = express()
server.use(bodyParser())
# Success page.
server.get "/", (req, res)->
  res.send "Success!"
# Not found
server.get "/404", (req, res)->
  res.send 404, "Not found"
# Internal error
server.get "/500", (req, res)->
  res.send 500, "Boom!"
# Multiple set-cookie headers
server.get "/set-cookie", (req, res)->
  res.cookie "c1", "v1"
  res.cookie "c2", "v2"
  res.send 200
# POST data
server.post "/post-data", (req, res)->
  res.send 200


# Setup environment for running tests.
running = false
setup = (callback)->
  if running
    process.nextTick(callback)
  else
    Async.parallel [
      (done)->
        HTTP.createServer(server)
          .listen(HTTP_PORT, done)
      (done)->
        HTTPS.createServer(SSL, server)
          .listen(HTTPS_PORT, done)
    ], (error)->
      running = true
      callback(error)


module.exports =
  setup:          setup
  HTTP_PORT:      HTTP_PORT
  HTTPS_PORT:     HTTPS_PORT
  INACTIVE_PORT:  INACTIVE_PORT
