{ assert, setup, HTTP, HTTPS, Replay } = require("./helpers")


# First batch is testing requests that pass through to the server, no recording/replay.
#
# Second batch is testing requests with no replay and no network access.
describe "Pass through", ->

  before setup

  # Send request to the live server on port 3001 and check the responses.
  describe "bloody", ->
    before ->
      Replay.mode = "bloody"

    describe "listeners", ->
      response = null

      before (done)->
        request = HTTP.get(hostname: "pass-through", port: 3001)
        request.on "response", (_)->
          response = _
          response.body = ""
          response.on "data", (chunk)->
            response.body += chunk
          response.on "end", done
        request.on "error", done
        
      it "should return HTTP version", ->
        assert.equal response.httpVersion, "1.1"
      it "should return status code", ->
        assert.equal response.statusCode, 200
      it "should return response trailers", ->
        assert.deepEqual response.trailers, { }
      it "should return response headers", ->
        assert.equal response.headers["content-type"], "text/html; charset=utf-8"
      it "should return response body", ->
        assert.deepEqual response.body, "Success!"


    describe "callback", ->
      response = null

      before (done)->
        request = HTTP.get(hostname: "pass-through", port: 3001, (_)->
          response = _
          response.body = ""
          response.on "data", (chunk)->
            response.body += chunk
          response.on "end", done
        )
        request.on "error", done
        
      it "should return HTTP version", ->
        assert.equal response.httpVersion, "1.1"
      it "should return status code", ->
        assert.equal response.statusCode, 200
      it "should return response headers", ->
        assert.equal response.headers["content-type"], "text/html; charset=utf-8"
      it "should return response trailers", ->
        assert.deepEqual response.trailers, { }
      it "should return response body", ->
        assert.deepEqual response.body, "Success!"


  describe "ssl", ->
    before ->
      Replay.mode = "bloody"

    response = null

    before (done)->
      request = HTTPS.get(hostname: "pass-through", port: 3443, (_)->
        response = _
        response.body = ""
        response.on "data", (chunk)->
          response.body += chunk
        response.on "end", done
      )
      request.on "error", done
      
    it "should return HTTP version", ->
      assert.equal response.httpVersion, "1.1"
    it "should return status code", ->
      assert.equal response.statusCode, 200
    it "should return response headers", ->
      assert.equal response.headers["content-type"], "text/html; charset=utf-8"
    it "should return response trailers", ->
      assert.deepEqual response.trailers, { }
    it "should return response body", ->
      assert.deepEqual response.body, "Success!"

  # Send request to the live server on port 3001, but this time network connection disabled.
  describe "replay", ->
    before ->
      Replay.mode = "replay"

    describe "listeners", ->
      error = null

      before (done)->
        request = HTTP.get(hostname: "pass-through", port: 3001)
        request.on "error", (_)->
          error = _
          done()

      it "should callback with error", ->
        assert error instanceof Error
        assert.equal error.code, "ECONNREFUSED"

