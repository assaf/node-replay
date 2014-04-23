{  setup, HTTP_PORT, HTTPS_PORT, INACTIVE_PORT } = require("./helpers")
assert  = require("assert")
File    = require("fs")
HTTP    = require("http")
HTTPS   = require("https")
Request = require("request")
Replay  = require("../src/replay")


# Test replaying results from fixtures in spec/fixtures.
describe "Replay", ->


  # Send responses to non-existent server on inactive port, expect replayed responses from fixtures.
  describe "matching URL", ->
    before ->
      Replay.mode = "replay"
      
    describe "listeners", ->
      before (done)->
        HTTP.get("http://example.com:#{INACTIVE_PORT}/weather?c=94606", (@response)=>
          done()
        ).on("error", done)

      it "should return HTTP version", ->
        assert.equal @response.httpVersion, "1.1"
      it "should return status code", ->
        assert.equal @response.statusCode, 200
      it "should return response headers", ->
        assert.deepEqual @response.headers, { "content-type": "text/html", "date": "Tue, 29 Nov 2011 03:12:15 GMT" }
      it "should return response trailers", ->
        assert.deepEqual @response.trailers, { }


    describe "callback", ->
      before (done)->
        HTTP.get(hostname: "example.com", port: INACTIVE_PORT, path: "/weather?c=94606", (@response)=>
          done()
        ).on("error", done)

      it "should return HTTP version", ->
        assert.equal @response.httpVersion, "1.1"
      it "should return status code", ->
        assert.equal @response.statusCode, 200
      it "should return response headers", ->
        assert.deepEqual @response.headers, { "content-type": "text/html", "date": "Tue, 29 Nov 2011 03:12:15 GMT" }
      it "should return response trailers", ->
        assert.deepEqual @response.trailers, { }


  describe "matching an https url", ->
    before ->
      Replay.mode = "replay"
    before (done)->
      HTTPS.get(hostname: "example.com", port: HTTPS_PORT, path: "/minimal", (@response)=>
        done()
      ).on("error", done)

    it "should return HTTP version", ->
      assert.equal @response.httpVersion, "1.1"
    it "should return status code", ->
      assert.equal @response.statusCode, 200


  describe "matching a regexp", ->
    before ->
      Replay.mode = "replay"

    before (done)->
      HTTP.get(hostname: "example.com", port: INACTIVE_PORT, method: "get", path: "/regexp", (response)=>
        @body = ""
        response.on "data", (chunk)=>
          @body += chunk
        response.on "end", done
      ).on("error", done)

    it "should match the right fixture", ->
      assert.equal @body, "regexp"


  describe "matching a regexp url with flags", ->
    before ->
      Replay.mode = "replay"

    before (done)->
      HTTP.get(hostname: "example.com", port: INACTIVE_PORT, method: "get", path: "/aregexp2", (response)=>
        @body = ""
        response.on "data", (chunk)=>
          @body += chunk
        response.on "end", done
      ).on("error", done)

    it "should match a fixture", ->
      assert.equal @body, "Aregexp2"

  describe "matching when changing fixtures dir", ->
    before ->
      Replay.mode = "replay"

    it "should match response before switch", (done)->
      doAsserts = ()=>
        assert.equal @response.headers.date, "Tue, 29 Nov 2011 03:12:15 GMT"
        assert.equal @body, "Nice and warm\n"
        done()

      HTTP.get(hostname: "example.com", port: INACTIVE_PORT, path: "/weather?c=94606", (@response)=>
        @body = ""
        @response.on "data", (chunk)=>
          @body += chunk
        @response.on "end", doAsserts
      ).on("error", done)

    it "should match response after switch", (done)->
      Replay.fixtures = "#{__dirname}/fixtures/other-fixtures-dir"

      doAsserts = ()=>
        assert.equal @response.headers.date, "Tue, 30 Nov 2011 03:12:15 GMT"
        assert.equal @body, "Sweet and cold\n"
        done()

      HTTP.get(hostname: "example.com", port: INACTIVE_PORT, path: "/weather?c=94606", (@response)=>
        @body = ""
        @response.on "data", (chunk)=>
          @body += chunk
        @response.on "end", doAsserts
      ).on("error", done)

    after ->
      Replay.fixtures = "#{__dirname}/fixtures"

  describe "recording multiple of the same header", ->

    before setup

    before ->
      Replay.mode = "record"
      Replay.allow "127.0.0.1"
      @fixturesDir = "#{__dirname}/fixtures/127.0.0.1-#{HTTP_PORT}"

    before (done)->
      HTTP.get(hostname: "127.0.0.1", port: HTTP_PORT, path: "/set-cookie", (response)->
        response.on("end", done)
      ).on("error", done)

    it "should create a fixture with multiple set-cookie headers", ->
      set_cookie_count = 0
      files = File.readdirSync(@fixturesDir)
      fixture = File.readFileSync("#{@fixturesDir}/#{files[0]}", "utf8")
      for line in fixture.split("\n")
        set_cookie_count++ if /set-cookie: c\d=v\d/.test(line)
      assert.equal set_cookie_count, 2

    describe "replaying multiple headers", ->

      before (done)->
        Request.get "http://127.0.0.1:#{HTTP_PORT}/set-cookie", (err, resp)=>
          @headers = resp.headers
          done()

      it "should have both set-cookie headers", ->
        assert.equal @headers["set-cookie"][0], "c1=v1; Path=/"
        assert.equal @headers["set-cookie"][1], "c2=v2; Path=/"

    after ->
      Replay.localhost "127.0.0.1"
      for file in File.readdirSync(@fixturesDir)
        File.unlinkSync("#{@fixturesDir}/#{file}")
      File.rmdir(@fixturesDir)


  describe "recording POST data", ->
    before setup

    before ->
      Replay.mode = "record"
      Replay.allow "127.0.0.1"
      @fixturesDir = "#{__dirname}/fixtures/127.0.0.1-#{HTTP_PORT}"

    before (done)->
      request = HTTP.request(hostname: "127.0.0.1", port: HTTP_PORT, method: "post", path: "/post-data", (response)->
        response.on("end", done)
      ).on("error", done)
      request.write("request data")
      request.end()

    it "should save POST request data", ->
      has_data = false
      files = File.readdirSync(@fixturesDir)
      fixture = File.readFileSync("#{@fixturesDir}/#{files[0]}", "utf8")
      for line in fixture.split("\n")
        has_data = true if line == "body: request data"
      assert has_data

    after ->
      Replay.localhost "127.0.0.1"
      for file in File.readdirSync(@fixturesDir)
        File.unlinkSync("#{@fixturesDir}/#{file}")
      File.rmdir(@fixturesDir)


  describe "recording multi-line POST data", ->
    before setup

    before ->
      Replay.mode = "record"
      Replay.allow "127.0.0.1"
      @fixturesDir = "#{__dirname}/fixtures/127.0.0.1-#{HTTP_PORT}"

    before (done)->
      request = HTTP.request(hostname: "127.0.0.1", port: HTTP_PORT, method: "post", path: "/post-data", (response)->
        response.on("end", done)
      ).on("error", done)
      request.write "line1\nline2\nline3"
      request.end()

    it "should save POST request data", ->
      files = File.readdirSync(@fixturesDir)
      fixture = File.readFileSync("#{@fixturesDir}/#{files[0]}", "utf8")
      assert fixture.split("\n")[1] == "body: line1\\nline2\\nline3"

    after ->
      Replay.localhost "127.0.0.1"
      for file in File.readdirSync(@fixturesDir)
        File.unlinkSync("#{@fixturesDir}/#{file}")
      File.rmdir(@fixturesDir)


  describe "replaying with POST body", ->
    before ->
      Replay.mode = "replay"

    describe "matching", ->
      before (done)->
        request = HTTP.request(hostname: "example.com", port: INACTIVE_PORT, path: "/post-body", method: "post")
        request.on "response", (@response)=>
          response.on "end", done
        request.on("error", done)
        request.write("request body")
        request.end()

      it "should return status code", ->
        assert.equal @response.statusCode, 200


  describe "replaying with multi-line POST body", ->
    before ->
      Replay.mode = "replay"

    describe "matching", ->
      before (done)->
        request = HTTP.request(hostname: "example.com", port: INACTIVE_PORT, path: "/post-body-multi", method: "post")
        request.on "response", (@response)=>
          response.on "end", done
        request.on("error", done)
        request.write """line1
        line2
        line3"""
        request.end()

      it "should return status code", ->
        assert.equal @response.statusCode, 200


  describe "only specified headers", ->

    before setup

    before ->
      Replay.mode = "record"
      Replay.allow "127.0.0.1"
      # Drop the /accept/ header
      Replay.headers = Replay.headers.filter((header)-> !header.test('accept'))
      @fixturesDir = "#{__dirname}/fixtures/127.0.0.1-#{HTTP_PORT}"

    before (done)->
      HTTP.get(hostname: "127.0.0.1", port: HTTP_PORT, path: "/", headers: { accept: "application/json" }, (response)->
        response.on("end", done)
      ).on("error", done)

    it "should not store the accept header", ->
      files = File.readdirSync(@fixturesDir)
      fixture = File.readFileSync("#{@fixturesDir}/#{files[0]}", "utf8")
      assert !/accept/.test fixture

    after ->
      Replay.localhost "127.0.0.1"
      for file in File.readdirSync(@fixturesDir)
        File.unlinkSync("#{@fixturesDir}/#{file}")
      File.rmdir(@fixturesDir)


  # Send responses to non-existent server on inactive port. No matching fixture for that path, expect a 404.
  describe "undefined path", ->
    before ->
      Replay.mode = "replay"

    before (done)->
      HTTP.get(hostname: "example.com", port: INACTIVE_PORT, path: "/weather?c=14003", done)
        .on "error", (@error)=>
          done()

    it "should callback with error", ->
      assert @error instanceof Error
      assert.equal @error.code, "ECONNREFUSED"


  # Send responses to non-existent server on inactive port. No matching fixture for that host, expect refused connection.
  describe "undefined host", ->
    before ->
      Replay.mode = "default"

    before (done)->
      HTTP.get(hostname: "no-such", port: INACTIVE_PORT, done)
        .on "error", (@error)=>
          done()

    it "should callback with error", ->
      assert @error instanceof Error
      assert.equal @error.code, "ECONNREFUSED"


  # Mapping specifies a header, make sure we only match requests that have that header value.
  describe "header", ->
    before ->
      Replay.mode = "replay"

    describe "matching", ->
      before (done)->
        request = HTTP.request(hostname: "example.com", port: INACTIVE_PORT, path: "/weather.json")
        request.setHeader "Accept", "application/json"
        request.on "response", (response)=>
          @statusCode = response.statusCode
          response.on "end", done
        request.on("error", done)
        request.end()

      it "should return status code", ->
        assert.equal @statusCode, 200

    describe "no match", ->
      before (done)->
        request = HTTP.request(hostname: "example.com", port: INACTIVE_PORT, path: "/weather.json")
        request.setHeader "Accept", "text/xml"
        request.on "response", (response)->
          response.on "end", done
        request.on "error", (@error)=>
          done()
        request.end()

      it "should fail to connnect", ->
        assert @error instanceof Error


  describe "method", ->
    before ->
      Replay.mode = "replay"

    describe "matching", ->
      before (done)->
        request = HTTP.request(hostname: "example.com", port: INACTIVE_PORT, method: "post", path: "/posts")
        request.setHeader "Accept", "application/json"
        request.on "response", (response)=>
          { @statusCode, @headers } = response
          response.on "end", done
        request.on "error", done
        request.end()

      it "should return status code", ->
        assert.equal @statusCode, 201
      it "should return headers", ->
        assert.equal @headers.location, "/posts/1"

    describe "no match", ->

      before (done)->
        request = HTTP.request(hostname: "example.com", port: INACTIVE_PORT, method: "put", path: "/posts")
        request.setHeader "Accept", "text/xml"
        request.on "response", (response)->
          response.on "end", done
        request.on "error", (@error)=>
          done()
        request.end()

      it "should fail to connnect", ->
        assert @error instanceof Error


  describe "minimal response", ->
    before ->
      Replay.mode = "replay"

    describe "listeners", ->
      before (done)->
        request = HTTP.get(hostname: "example.com", port: INACTIVE_PORT, path: "/minimal")
        request.on "response", (@response)=>
          @response.body = null
          @response.on "data", (chunk)=>
            # This will fail, no response.body
            @response.body += chunk
          @response.on "end", done
        request.on "error", done

      it "should return HTTP version", ->
        assert.equal @response.httpVersion, "1.1"
      it "should return status code", ->
        assert.equal @response.statusCode, 200
      it "should return no response headers", ->
        assert.deepEqual @response.headers, { }
      it "should return no response trailers", ->
        assert.deepEqual @response.trailers, { }
      it "should return no response body", ->
        assert !@response.body

