DNS           = require("dns")
HTTP          = require("http")
HTTPS         = require("https")
ProxyRequest  = require("./proxy")
Replay        = require("./replay")
URL           = require("url")


httpRequest = HTTP.request


# Route HTTP requests to our little helper.
HTTP.request = (options, callback)->
  if typeof(options) == "string" || options instanceof String
    options = URL.parse(options)

  # WebSocket request: pass through to Node.js library
  if options.headers && options.headers["Upgrade"] == "websocket"
    return httpRequest(options, callback)
  hostname = options.hostname || (options.host && options.host.split(":")[0]) || "localhost"
  if Replay.isLocalhost(hostname) || Replay.isAllowed(hostname)
    return httpRequest(options, callback)

  # Proxy request
  request = new ProxyRequest(options, Replay.chain.start)
  if callback
    request.once("response", callback)
  return request


# HTTP.get is shortcut for HTTP.request
HTTP.get = (options, callback)->
  request = HTTP.request(options, callback)
  request.end()
  return request


# Route HTTPS requests
HTTPS.request = (options, callback)->
  options.protocol = "https:"
  return HTTP.request(options, callback)


# Redirect HTTP requests to 127.0.0.1 for all hosts defined as localhost
original_lookup = DNS.lookup
DNS.lookup = (domain, options, callback)->
  if typeof(options) == "function"
    [family, callback] = [4, options]
    options = family
  else if typeof(options) == "object"
    family = options.family
  else
    family = options

  if Replay.isLocalhost(domain)
    # io.js options is an object, Node 0.10 family number
    if family == 6
      callback(null, "::1", 6)
    else
      callback(null, "127.0.0.1", 4)
  else
    original_lookup(domain, options, callback)


module.exports = Replay
