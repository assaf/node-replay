# Used to capture actual HTTP response and replay it later.
class CaptureResponse
  constructor: (@request, @parts)->

  capture: (callback)->
    @request.on "response", (response)=>
      captured =
        version:  response.httpVersion
        status:   response.statusCode
        headers:  {}
        body:     []
        trailers: {}
      headers = captured.headers
      for name, value of response.headers
        headers[name.toLowerCase()] = value

      response.on "data", (chunk)->
        captured.body.push [chunk]
      response.on "end", ->
        trialers = captured.trailers
        for name, value of response.trailers
          trailers[name.toLowerCase()] = value
        callback null, captured

    @request.on "error", (error)->
      callback error

    if @parts
      for part in @parts
        @request.write @parts[0], @parts[1]
    @request.end()

exports.CaptureResponse = CaptureResponse
