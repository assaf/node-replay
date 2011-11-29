{ assert, vows, HTTP } = require("./helpers")


vows.describe("Replay").addBatch

  "from URL":
    topic: ->
      request = HTTP.get(host: "example.com", path: "/weather?c=94606")
      request.on "response", (response)=>
        response.on "end", =>
          @callback null, response
      request.on "error", (error)=>
        @callback error
      request.end()
    "should return HTTP version": (response)->
      assert.equal response.httpVersion, "1.1"
    "should return status code": (response)->
      assert.equal response.statusCode, "200"
    "should return response headers": (response)->
      assert.deepEqual response.headers, { "content-type": "text/html", "date": "Tue, 29 Nov 2011 03:12:15 GMT" }
    "should return response trailers": (response)->
      assert.deepEqual response.trailers, { }

.export(module)
