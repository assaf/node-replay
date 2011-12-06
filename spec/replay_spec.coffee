{ assert, vows, HTTP, Replay } = require("./helpers")


# Test replaying results from fixtures in spec/fixtures.
vows.describe("Replay").addBatch

  # Send responses to non-existent server on port 3002, expect replayed responses from fixtures.
  "matching URL":
    topic: ->
      Replay.mode = "replay"
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
      Replay.mode = "replay"
      request = HTTP.get(hostname: "example.com", port: 3002, path: "/weather?c=14003", (response)=>
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

  
  # Send responses to non-existent server on port 3002. No matching fixture for that host, expect refused connection.
  "undefined host":
    topic: ->
      Replay.mode = "default"
      request = HTTP.get(hostname: "no-such", port: 3002, (response)=>
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


  "header":
    topic: ->
      Replay.mode = "replay"
      @callback null
    "matching":
      topic: ->
        request = HTTP.request(hostname: "example.com", port: 3002, path: "/weather.json")
        request.setHeader "Accept", "application/json"
        request.on "response", (response)=>
          response.on "end", =>
            @callback null, response
        request.on "error", @callback
        request.end()
        return
      "should return status code": (response)->
        assert.equal response.statusCode, "200"

    "no match":
      topic: ->
        request = HTTP.request(hostname: "example.com", port: 3002, path: "/weather.json")
        request.setHeader "Accept", "text/xml"
        request.on "response", (response)=>
          response.on "end", =>
            @callback null, response
        request.on "error", (error)=>
          @callback null, error
        request.end()
        return
      "should fail to connnect": (response)->
        assert.instanceOf response, Error


.export(module)
