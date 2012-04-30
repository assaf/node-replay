{ assert, HTTP, Replay } = require("./helpers")


# Test replaying results from fixtures in spec/fixtures.
describe "Replay", ->


  # Send responses to non-existent server on port 3002, expect replayed responses from fixtures.
  describe "matching URL", ->
    before ->
      Replay.mode = "replay"
      
    describe "listeners", ->
      response = null

      before (done)->
        request = HTTP.get(hostname: "example.com", port: 3002, path: "/weather?c=94606")
        request.on "response", (_)->
          response = _
          response.on "end", done
        request.on "error", done

      it "should return HTTP version", ->
        assert.equal response.httpVersion, "1.1"
      it "should return status code", ->
        assert.equal response.statusCode, 200
      it "should return response headers", ->
        assert.deepEqual response.headers, { "content-type": "text/html", "date": "Tue, 29 Nov 2011 03:12:15 GMT" }
      it "should return response trailers", ->
        assert.deepEqual response.trailers, { }


    describe "callback", ->
      response = null

      before (done)->
        request = HTTP.get(hostname: "example.com", port: 3002, path: "/weather?c=94606")
        request.on "response", (_)->
          response = _
          done()
        request.on "error", done

      it "should return HTTP version", ->
        assert.equal response.httpVersion, "1.1"
      it "should return status code", ->
        assert.equal response.statusCode, 200
      it "should return response headers", ->
        assert.deepEqual response.headers, { "content-type": "text/html", "date": "Tue, 29 Nov 2011 03:12:15 GMT" }
      it "should return response trailers", ->
        assert.deepEqual response.trailers, { }


  describe "matching a regexp", ->
    body = null

    before ->
      Replay.mode = "replay"

    before (done)->
      request = HTTP.get(hostname: "example.com", port: 3002, method: "post", path: "/regexp", (response)->
        body = ""
        response.on "data", (chunk)->
          body += chunk
        response.on "end", done
      )
      request.on "error", done

    it "should match the right fixture", ->
      assert.equal body, "regexp"


  describe "matching a regexp url with flags", ->
    body = null

    before ->
      Replay.mode = "replay"

    before (done)->
      request = HTTP.get(hostname: "example.com", port: 3002, method: "post", path: "/aregexp2", (response)->
        body = ""
        response.on "data", (chunk)->
          body += chunk
        response.on "end", done
      )
      request.on "error", done

    it "should match a fixture", ->
      assert.equal body, "Aregexp2"


  # Send responses to non-existent server on port 3002. No matching fixture for that path, expect a 404.
  describe "undefined path", ->
    error = null

    before ->
      Replay.mode = "replay"

    before (done)->
      request = HTTP.get(hostname: "example.com", port: 3002, path: "/weather?c=14003", done)
      request.on "response", done
      request.on "error", (_)->
        error = _
        done()

    it "should callback with error", ->
      assert error instanceof Error
      assert.equal error.code, "ECONNREFUSED"

  
  # Send responses to non-existent server on port 3002. No matching fixture for that host, expect refused connection.
  describe "undefined host", ->
    error = null

    before ->
      Replay.mode = "default"

    before (done)->
      request = HTTP.get(hostname: "no-such", port: 3002)
      request.on "response", done
      request.on "error", (_)->
        error = _
        done()

    it "should callback with error", ->
      assert error instanceof Error
      assert.equal error.code, "ECONNREFUSED"


  # Mapping specifies a header, make sure we only match requests that have that header value.
  describe "header", ->
    before ->
      Replay.mode = "replay"

    describe "matching", ->
      statusCode = null

      before (done)->
        request = HTTP.request(hostname: "example.com", port: 3002, path: "/weather.json")
        request.setHeader "Accept", "application/json"
        request.on "response", (response)->
          statusCode = response.statusCode
          response.on "end", done
        request.on "error", done
        request.end()

      it "should return status code", ->
        console.dir arguments
        assert.equal statusCode, 200

    describe "no match", ->
      error = null

      before (done)->
        request = HTTP.request(hostname: "example.com", port: 3002, path: "/weather.json")
        request.setHeader "Accept", "text/xml"
        request.on "response", (response)->
          response.on "end", done
        request.on "error", (_)->
          error = _
          done()
        request.end()

      it "should fail to connnect", ->
        assert error instanceof Error


  describe "method", ->
    statusCode = headers = null

    before ->
      Replay.mode = "replay"

    describe "matching", ->
      before (done)->
        request = HTTP.request(hostname: "example.com", port: 3002, method: "post", path: "/posts")
        request.setHeader "Accept", "application/json"
        request.on "response", (response)->
          { statusCode, headers } = response
          response.on "end", done
        request.on "error", done
        request.end()

      it "should return status code", ->
        assert.equal statusCode, 201
      it "should return headers", ->
        assert.equal headers.location, "/posts/1"

    describe "no match", ->
      error = null

      before (done)->
        request = HTTP.request(hostname: "example.com", port: 3002, method: "put", path: "/posts")
        request.setHeader "Accept", "text/xml"
        request.on "response", (response)->
          response.on "end", done
        request.on "error", (_)->
          error = _
          done()
        request.end()

      it "should fail to connnect", ->
        assert error instanceof Error


  describe "minimal response", ->
    before ->
      Replay.mode = "replay"

    describe "listeners", ->
      response = null

      before (done)->
        request = HTTP.get(hostname: "example.com", port: 3002, path: "/minimal")
        request.on "response", (_)->
          response = _
          response.body = null
          response.on "data", (chunk)->
            # This will fail, no response.body
            response.body += chunk
          response.on "end", done
        request.on "error", done

      it "should return HTTP version", ->
        assert.equal response.httpVersion, "1.1"
      it "should return status code", ->
        assert.equal response.statusCode, 200
      it "should return no response headers", ->
        assert.deepEqual response.headers, { }
      it "should return no response trailers", ->
        assert.deepEqual response.trailers, { }
      it "should return no response body", ->
        assert !response.body

