{ assert, vows, HTTP, Replay } = require("./helpers")


# Test replaying results from fixtures in spec/fixtures.
vows.describe("Replay").addBatch

  # Send responses to non-existent server on port 3002, expect replayed responses from fixtures.
  "matching URL":
    topic: ->
      Replay.networkAccess = false
      Replay.record = false
      @callback null
    "listeners":
      topic: ->
        request = HTTP.get(hostname: "example.com", port: 3002, path: "/weather?c=94606")
        request.on "response", (response)=>
          response.on "end", =>
            @callback null, response
        request.on "error", @callback
        return
      "should return HTTP version": (response)->
        assert.equal response.httpVersion, "1.1"
      "should return status code": (response)->
        assert.equal response.statusCode, "200"
      "should return response headers": (response)->
        assert.deepEqual response.headers, { "content-type": "text/html", "date": "Tue, 29 Nov 2011 03:12:15 GMT" }
      "should return response trailers": (response)->
        assert.deepEqual response.trailers, { }

    "callback":
      topic: ->
        request = HTTP.get(hostname: "example.com", port: 3002, path: "/weather?c=94606", (response)=>
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
        assert.deepEqual response.headers, { "content-type": "text/html", "date": "Tue, 29 Nov 2011 03:12:15 GMT" }
      "should return response trailers": (response)->
        assert.deepEqual response.trailers, { }


  # Send responses to non-existent server on port 3002. No matching fixture for that path, expect a 404.
  "undefined path":
    topic: ->
      Replay.networkAccess = false
      HTTP.get hostname: "example.com", port: 3002, path: "/weather?c=14003", (response)=>
        response.body = ""
        response.on "data", (chunk)->
          response.body += chunk
        response.on "end", =>
          @callback null, response
      return
    "should return HTTP version": (response)->
      assert.equal response.httpVersion, "1.1"
    "should return status code 404": (response)->
      assert.equal response.statusCode, "404"
    "should return body with error message": (response)->
      assert.equal response.body, "No recorded request/response that matches http://example.com:3002/weather?c=14003"


  
  # Send responses to non-existent server on port 3002. No matching fixture for that host, expect refused connection.
  "undefined host":
    topic: ->
      Replay.networkAccess = false
      request = HTTP.get(hostname: "no-such", port: 3002, path: "/weather?c=14003", (response)=>
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
