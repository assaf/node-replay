HTTP = require("http")

# Capture original HTTP request. PassThrough proxy uses that.
httpRequest = HTTP.request

exports.passThrough = (allow)->
  if arguments.length == 0
    allow = -> true
  else if typeof allow == "string"
    [hostname, allow] = [allow, (request)-> request.hostname == hostname]
  else unless typeof allow == "function"
    [boolean, allow] = [allow, (request)-> !!boolean]
  return (request, callback)->
    if allow(request)
      options =
        hostname: request.url.hostname
        port:     request.url.port
        path:     request.url.path
        method:   request.method
        headers:  request.headers
      http = httpRequest(options)
      http.on "error", (error)->
        callback error
      http.on "response", (response)->
        captured =
          version: response.httpVersion
          status:  response.statusCode
          headers: response.headers
          body:    []
        response.on "data", (chunk)->
          captured.body.push chunk
        response.on "end", ->
          captured.trailers = response.trailers
          callback null, captured
      if request.body
        for part in request.body
          http.write part[0], part[1]
      http.end()
    else
      callback null
