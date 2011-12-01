{ assert, setup, vows, HTTP, Replay } = require("./helpers")


# First batch is testing requests that pass through to the server, no recording/replay.
#
# Second batch is testing requests with no replay and no network access.
vows.describe("Pass through").addBatch

  # Send request to the live server on port 3001 and check the responses.
  "live server":
    topic: ->
      Replay.networkAccess = true
      Replay.record = false
      setup @callback
    "listeners":
      topic: ->
        request = HTTP.get(hostname: "pass-through", port: 3001)
        request.on "response", (response)=>
          response.body = ""
          response.on "data", (chunk)->
            response.body += chunk
          response.on "end", =>
            @callback null, response
        request.on "error", @callback
        return
      "should return HTTP version": (response)->
        assert.equal response.httpVersion, "1.1"
      "should return status code": (response)->
        assert.equal response.statusCode, "200"
      "should return response trailers": (response)->
        assert.deepEqual response.trailers, { }
      "should return response headers": (response)->
        assert.equal response.headers["content-type"], "text/html; charset=utf-8"
      "should return response body": (response)->
        assert.deepEqual response.body, "Success!"

    "callback":
      topic: ->
        request = HTTP.get(hostname: "pass-through", port: 3001, (response)=>
          response.body = ""
          response.on "data", (chunk)->
            response.body += chunk
          response.on "end", =>
            @callback null, response
        )
        request.on "error", @callback
        return
      "should return HTTP version": (response)->
        assert.equal response.httpVersion, "1.1"
      "should return status code": (response)->
        assert.equal response.statusCode, "200"
      "should return response headers": (response)->
        assert.equal response.headers["content-type"], "text/html; charset=utf-8"
      "should return response trailers": (response)->
        assert.deepEqual response.trailers, { }
      "should return response body": (response)->
        assert.deepEqual response.body, "Success!"


.addBatch

  # Send request to the live server on port 3001, but this time network connection disabled.
  "live server":
    topic: ->
      Replay.networkAccess = false
      Replay.record = false
      setup @callback
    "listeners":
      topic: ->
        request = HTTP.get(hostname: "pass-through", port: 3001, (response)=>
          @callback null, "callback"
        )
        request.on "response", (response)=>
          @callback null, "listener"
        request.on "error", (error)=>
          @callback null, error
        return
      "should callback with error": (error)->
        assert.instanceOf error, Error
        assert.equal error.code, "ECONNREFUSED"


.export(module)
