DNS           = require("dns")
HTTP          = require("http")
ProxyRequest  = require("./proxy")
Replay        = require("./replay")


# Route HTTP requests to our little helper.
HTTP.request = (options, callback)->
  request = new ProxyRequest(options, Replay.chain.start)
  if callback
    request.once "response", (response)->
      callback response
  return request


# Redirect HTTP requests to 127.0.0.1 for all hosts defined as localhost
original_lookup = DNS.lookup
DNS.lookup = (domain, callback)->
  unless callback
    [family, callback] = [null, family]
  if Replay.isLocalhost[domain]
    callback null, "127.0.0.1", 4
  else
    original_lookup domain, callback


module.exports = Replay
