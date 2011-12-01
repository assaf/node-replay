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
      http = httpRequest(request.url)
      http.on "error", (error)->
        callback error
      http.on "response", (response)->
        body = []
        response.on "data", (chunk)->
          body.push chunk
        response.on "end", ->
          callback null, { status: response.statusCode, headers: response.headers, body: body }
      http.end()
    else
      callback null
