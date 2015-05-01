{ setup, HTTP_PORT, HTTPS_PORT } = require("./helpers")
assert  = require("assert")
HTTP    = require("http")
HTTPS   = require("https")
Replay  = require("../src/replay")


# First batch is testing requests that pass through to the server, no recording/replay.
#
# Second batch is testing requests with no replay and no network access.
describe "Pass through", ->

  before(setup)

  # Send request to the live server and check the responses.
  describe "bloody", ->
    before ->
      Replay.mode = "bloody"

    describe "listeners", ->
      response = null

      before (done)->
        request = HTTP.get(hostname: "pass-through", port: HTTP_PORT)
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

    after ->
      Replay.mode = "replay"


    describe "callback", ->
      response = null

      before (done)->
        request = HTTP.get(hostname: "pass-through", port: HTTP_PORT, (_)->
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

    after ->
      Replay.mode = "replay"


  describe "ssl", ->
    before ->
      # Make sure we're using passThrough and not just passing request s
      # through HTTP.request
      Replay.mode = "bloody"
      process.env.NODE_TLS_REJECT_UNAUTHORIZED = 0

    response = null

    describe "get", ->
      before (done)->
        options =
          method:   "GET"
          hostname: "pass-through"
          port:     HTTPS_PORT
          agent:    false
          rejectUnauthorized: false
        request = HTTPS.request(options, (_)->
          response = _
          response.body = ""
          response.on "data", (chunk)->
            response.body += chunk
          response.on "end", ->
          response.on "end", done
        )
        request.on("error", done)
        request.end()

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

    describe "post", ->
      before (done)->
        body = new Buffer("foo=bar")

        options =
          method:   "POST"
          hostname: "pass-through"
          port:     HTTPS_PORT
          agent:    false
          path:     "/post-echo"
          headers:  {'content-type': 'application/x-www-form-urlencoded', 'content-length': body.length}
          rejectUnauthorized: false
        request = HTTPS.request(options, (_)->
          response = _
          response.body = ""
          response.on "data", (chunk)->
            response.body += chunk
          response.on "end", ->
          response.on "end", done
        )
        request.write(body)
        request.on("error", done)
        request.end()

      it "should return status code", ->
        assert.equal response.statusCode, 200
      it "should post the body", ->
        assert.equal response.body, JSON.stringify({foo: "bar"})

    after ->
      Replay.mode = "replay"


  # Send request to the live server, but this time network connection disabled.
  describe "replay", ->
    before ->
      Replay.mode = "replay"

    describe "listeners", ->
      error = null

      before (done)->
        request = HTTP.get(hostname: "pass-through", port: HTTP_PORT)
        request.on "error", (_)->
          error = _
          done()

      it "should callback with error", ->
        assert error instanceof Error
        assert.equal error.code, "ECONNREFUSED"

