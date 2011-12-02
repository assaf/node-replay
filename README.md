# Node Replay
   

### When API testing slows you down: mock, record and replay HTTP requests/responses like a boss

Things that will ruin your day if your tests make HTTP requests to other services:

- Other service is as or less reliable than Twitter's API
- Network late ............ ncy
- Being-rate limited and having to wait an hour between tests
- Same request returns different result on each run
- Everyone else on the network is deep in BitTorrent terittory

Things **node-replay** can do to make these problems go away:

- Record API response once, replay as often as necessary
- Stub HTTP request (TBD)
- Replay different responses to given request to test error handling
- Not suck


## How to use node-replay

Install (or add to your `package.json`):

    $ npm install replay

Like this:

    assert = require("assert")
    http = require("http")
    replay = require("replay")

    http.get({ hostname: "www.iheartquotes.com", path: "/api/v1/random" }, function(response) {
      response.body = "";
      response.on("data", function(chunk) {
        response.body = response.body + chunk;
      })
      response.on("end", function() {

        // Now check the request we made to the I <3 Quotes API
        assert.equal(response.statusCode, 200);
        assert.equal(response.body, "Oxymoron 2. Exact estimate\n\n[codehappy] http://iheartquotes.com/fortune/show/38021\n");
        console.log("Woot!");

      })
    })

This, of course, will fail the first time you run.  You'll see:

    Error: Connection to http://www.iheartquotes.com:80/api/v1/random refused: not recording and no network access
        at Array.0 (/Users/assaf/projects/node-replay/lib/replay/proxy.coffee:87:21)
        at EventEmitter._tickCallback (node.js:192:40)

The default mode is called `replay`, and in that mode *node-replay* will replay any previously captured HTTP responses,
but will not allow any outgoing network connection.  That's the default mode for running tests.  Why?  It guarantees all
tests will run against recorded responses, in other words: repeatable.

Repeatable tests are a Good Thing.

So the first thing you want to do is get *node-replay* to record that HTTP request and response, so it can replay it
later.  Let's put it in record mode:

    $ REPLAY=record node test.js

This test will also fail, but for a slightly different reason.  You see, requesting a random quotes returns a different
quote each time.  We're testing for a very particular quote.  So now we have two choices.

First, fix the test.  The error message will show you the actual quote recorded, change the assertion test to reflect
that.  Now run the test again:

    $ node test.js
    Woot!

Did the tests pass?  Of course they did.  Run it again.  Did they pass the second time?  Why, yes.

Your tests are now run by replaying the same recorded response.  You can see all the recorded responses for *I <3
Quotes* here:

    $ ls fixtures/www.iheartquotes.com/

There should be only one file to begin with, we only recorded one response.  Feel free to rename the file to something
more descriptive.  Try editing it and running the tests again.

You see, the second option, which is quite useful some times, e.g. if you need to simulate a response you can't easily
generate, is to record a response and then edit it.  So instead of changing the test, let's change the recorded response
to look like this:

    /api/v1/random

    200 HTTP/1.1
    server: nginx/0.7.67
    date: Fri, 02 Dec 2011 02:58:03 GMT
    content-type: text/plain
    connection: keep-alive
    etag: "a7131ebc1e81e43ea9ecf36fa2fdf610"
    x-ua-compatible: IE=Edge,chrome=1
    x-runtime: 0.158080
    cache-control: max-age=0, private, must-revalidate
    content-length: 234
    x-varnish: 2274830138
    age: 0
    via: 1.1 varnish

    Oxymoron 2. Exact estimate

    [codehappy] http://iheartquotes.com/fortune/show/38021

All responses are stored as text files using the simplest format ever, so you can edit them in Vim, or any of the many
other non-Vim text editors in existence:

- First come the request path (including query string).
- Next headers sent as part of the request (e.g. `Accept`, `Authorization`)
- Then an empty line
- Next the response status code and (optional) HTTP version number
- Followed by any headers sent as part of the response
- Then another empty line
- The rest is the response body


## Settings

We've got them.

The first and most obvious is the mode you run *node-reply* in, which can be one of:

**bloody** -- Allows outbound HTTP requests and doesn't replay anything.  Use this if you want to remember what life was
before you started using `node-replay`.  Also, to test your code against changes to 3rd party API, because these do
happen.  All too often.

**cheat** -- Allows outbound HTTP requests, but replays recorded responses.  This is mighty convenient when you're
working on new tests or code changes that make new, unrecorded HTTP requests, but you've not quite settled on the code
and you don't want to record any responses yet.

**record** -- Replays recorded responses, or captures responses for future replay.  Use this whenever you're working on
a test or code change that makes a new HTTP request, to capture and record that request.

**replay** -- Does not allow outbound HTTP requests, replays recorded responses.  This is the default mode.  That's
another way of saying, "you'll be using this mode most often".

Of course, *node-reply* needs to store all those captured responses somewhere, and by default it will put them in the
directory `fixtures`.  You'll probably want to find a more suitable home that matches the directory structure of your
application.

Like this:

    var replay = require("replay");
    replay.fixtures = __dirname + "/fixtures/replay"


If you're running into trouble, try turning debugging mode on.  It helps.  Sometimes.

    $ DEBUG=true node test.js
    Requesting http://www.iheartquotes.com:80/api/v1/random
    Woot!


## Geeking

To make all that magic possible, *node-replay* replaces `require('http').request` with its own method.  The replacement
method returns a `ProxyRequest` object that captures the request options, headers and body.

When it's time to fire the request, it gets sent through a chain of proxies.  The first proxy to have a response and
return it (via callback) terminates the chain.  If a proxy doesn't have a response, it will still call that callback,
with no arguments.  The request will then pass to the next proxy in the chain.

The proxy chain looks something like this:

- Logger dumps the request URL when `DEBUG=true`
- The pass-through proxy will pass the request to the actual endpoint in `bloody` mode, or when talking to `localhost`
- The recorder proxy will either replay a captured request or talk to the actual endpoint and record the response,
  depending on the mode
- The pass-through proxy will pass the request to the actual endpoint in `cheat` mode

The pass-through proxy uses Node's HTTP client to send a request and capture the response, so it can be stored and
replayed.

The recorder proxy either replays a response from memory, or uses pass-through to get a response, store it, and replay
it on the spot.

Loading pre-recorded responses to memory, from where they can be replayed, and storing new ones on disk, is handled by
the `Catalog`.


## Final words

*node-replay* is released under the MIT license.  Pull requests are welcome.


