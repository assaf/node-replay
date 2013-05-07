passThrough = require("./pass_through")


recorded = (settings)->
  catalog = settings.catalog
  capture = passThrough(true)
  return (request, callback)->
    host = request.url.hostname
    if request.url.port && request.url.port != "80"
      host += ":#{request.url.port}"
    # Look for a matching response and replay it.
    matchers = catalog.find(host)
    if matchers
      for matcher in matchers
        response = matcher(request)
        if response
          callback null, response
          return

    # Do not record this host.
    if settings.isIgnored(request.url.hostname)
      callback null
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
