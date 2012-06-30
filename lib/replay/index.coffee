DNS           = require("dns")
HTTP          = require("http")
HTTPS         = require("https")
ProxyRequest  = require("./proxy")
Replay        = require("./replay")


httpRequest = HTTP.request


# Route HTTP requests to our little helper.
HTTP.request = (options, callback)->
  # WebSocket request: pass through to Node.js library
  if options && options.headers && options.headers["Upgrade"] == "websocket"
    return httpRequest(options, callback)
  # Proxy request
  request = new ProxyRequest(options, Replay, Replay.chain.start)
  if callback
    request.once "response", (response)->
      callback response
  return request


# Route HTTPS requests
HTTPS.request = (options, callback)->
  options.protocol = "https:"
  return HTTP.request(options, callback)


# Redirect HTTP requests to 127.0.0.1 for all hosts defined as localhost
original_lookup = DNS.lookup
DNS.lookup = (domain, family, callback)->
  unless callback
    [family, callback] = [null, family]
  if Replay.isLocalhost(domain)
    if family == 6
      callback null, "::1", 6
    else
      callback null, "127.0.0.1", 4
  else
    original_lookup domain, family, callback


module.exports = Replay
