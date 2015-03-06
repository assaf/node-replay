HTTP = require("http")
HTTPS = require("https")


# Capture original HTTP request. PassThrough proxy uses that.
httpRequest  = HTTP.request
httpsRequest = HTTPS.request

passThrough = (allow)->
  if arguments.length == 0
    allow = -> true
  else if typeof allow == "string"
    [hostname, allow] = [allow, (request)-> request.hostname == hostname]
  else unless typeof allow == "function"
    [boolean, allow] = [allow, (request)-> !!boolean]

  return (request, callback)->
    if allow(request)
      options =
        protocol: request.url.protocol
        hostname: request.url.hostname
        port:     request.url.port
        path:     request.url.path
        method:   request.method
        headers:  request.headers
        agent:    request.agent
        auth:     request.auth

      http = httpRequest(options)
      if (request.trailers)
        http.addTrailers(request.trailers)
      http.on "error", (error)->
        callback error
      http.on "response", (response)->
        captured =
          version:        response.httpVersion
          statusCode:     response.statusCode
          statusMessage:  response.statusMessage
          headers:        response.headers
          rawHeaders:     response.rawHeaders
          body:    []
        response.on "data", (chunk, encoding)->
          captured.body.push([chunk, encoding])
        response.on "end", ->
          captured.trailers     = response.trailers
          captured.rawTrailers  = response.rawTrailers
          callback null, captured

      if request.body
        for part of request.body
          http.write(part[0], part[1])
      http.end()
    else
      callback null


module.exports = passThrough
