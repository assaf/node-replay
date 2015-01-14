passThrough = require("./pass_through")


recorded = (settings)->
  catalog = settings.catalog
  capture = passThrough(true)
  return (request, callback)->
    host = request.url.hostname
    if request.url.port && request.url.port != "80"
      host += ":#{request.url.port}"
    # Look for a matching response and replay it.
    try
      matchers = catalog.find(host)
      if matchers
        for matcher in matchers
          response = matcher(request)
          if response
            callback null, response
            return
    catch error
      error.code = "CORRUPT FIXTURE"
      error.syscall = "connect"
      callback error
      return


    # Do not record this host.
    if settings.isIgnored(request.url.hostname)
      refused = new Error("Error: connect ECONNREFUSED")
      refused.code = refused.errno = "ECONNREFUSED"
      refused.syscall = "connect"
      callback refused
      return

    # In recording mode capture the response and store it.
    if settings.mode == "record"
      capture request, (error, response)->
        return callback error if error
        catalog.save host, request, response, (error)->
          callback error, response
      return

    # Not in recording mode, pass control to the next proxy.
    callback null

module.exports = recorded
