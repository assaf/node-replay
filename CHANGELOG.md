## Version 1.10.3 2014-04-19

ADDED 127.0.0.1 to default localhost addresses (Rajit Singh)

FIXED double callback issue on catalog save (Itay Adler)


## Version 1.10.2 2014-04-19

FIXED bug with header stringifying (for realz now)


## Version 1.10.1 2014-04-19

FIXED bug with header stringifying

CHANGED run with DEBUG=replay or DEBUG=all


## Version 1.10.0 2014-04-18

CHANGED Support recording and serving images (Rajit).

CHANGED Support dynamic switching of fixtures (Pål Ruud):

  Replay.fixtures = "fixture-directory-2"

FIXED compatibility with superagent and supertest (Jerome Touffe-Blin)

FIXED support http.get([string]) 

FIXED request headers are stringified before processing


## Version 1.9.1 2013-12-05

Fix "Recursive nextTick" warning (Drew Stokes)


## Version 1.9.0 2013-11-04

Added support for specifying which headers are stored when recording, and used
for matching when replaying.  Edit the list of regular expressions in
`Replay.headers`.

Fixed a bug in capturing and filtering on POST request body.


## Version 1.8.0 2013-10-01

Added support for capturing and filtering on POST request body (Jerome
Gravel-Niquet)


## Version 1.7.0 2013-05-06

Support Windows by creating directories of the form host-port instead of
host:port.

Updated dev dependencies, testing with Express 3.2.


## Version 1.6.2 2013-03-19

Add randomness to uid to deal with fast requests and timekeeper (Nate Murray).

Add support for HTTPS (Nate Murray).

Tested with Node 0.10.0.


## Version 1.6.1 2013-02-18

Improved logging options:
- Replay will now emit errors to the console unless otherwise told
- You can tell Replay to not emit errors to console by setting
  Replay.silent = true
- You can also tell Replay to emit errors an logs messages elsewhere by setting
  Replay.logger (defaults to console)
- You can listen to all events via Replay.on("error", function(error) { })

No deprecation messages on Node 0.8.

Do not assume /tmp directory exists.

Works with request 2.11 by implementing a do nothing response.connection event


## Version 1.5.3 2012-06-30

Removed engine dependency. Works on 0.8.1 now.


## Version 1.5.2 2012-05-15

Do not fail on headers with empty value.


## Version 1.5.1 2012-05-14

When matching request against headers, also match the Authorization header
(David John).


## Version 1.5.0 2012-05-08

Properly handle repeating headers (e.g. set-cookie) by storing and reading
multiple entries.


## Version 1.4.4 2012-05-02

Filter out request headers *not* response headers.


## Version 1.4.3 2012-05-02

Precompile before publishing, no longer requires Coffee-Script to run.


## Version 1.4.2 2012-05-02

Added support for HTTPS (Jerome Gravel-Niquet)


## Version 1.4.1 2012-04-30

Do not store request headers we don't care for.


## Version 1.4.0 2012-04-30

Replay files can now use REGEXP to match request URL (Jerome Gravel-Niquet)


## Version 1.3.1 2012-03-15

Accept replay documents with nothing but method and path.


## Version 1.3.0 2012-03-15

Fix status code being string instead of integer.

Fix handling of fixtures with empty body.


## Version 1.2.3 2012-01-16

Support (or don't fail on) Web Sockets.

Fix non-working `Replay.localhost`.


## Version 1.2.2 2011-12-27

There may be hosts you don't care to record/replay: it doesn't matter if requests to these hosts succeed or not, and you
don't care to manage their recorded file.  You can just add those to the ignore list:

    Replay.ignore "www.google-analytics.com", "airbrake.io"

The `allow`, `ignore` and `localhost` methods now accept multiple arguments. 


## Version 1.2.1 2011-12-27

Bug fix to DNS hack.


## Version 1.2.0 2011-12-27

You can tell **node-replay** what hosts to treat as "localhost".  Requests to these hosts will be routed to 127.0.0.1,
without capturing or replay.  This is particularly useful if you're making request to a test server and want to use the
same URL as production.

For example:

    Replay.localhost "www.example.com"

Likewise, you can tell **node-reply** to allow network access to specific hosts.  These requests can still be recorded
and replayed, but will otherwise pass through to the specified host:

    Replay.allow "logger.example.com"


## Version 1.1.1 2011-12-06

Only store specific request headers (e.g. `Accept` but not `User-Agent`).


## Version 1.1.0 2011-12-05

Recorded response now starts with <method> <path>.
    
Examples:
    GET /weather?c=94606
    POST /posts


## Version 1.0.1 2011-12-05

Fix pathname and support matching request headers.


## Version 1.0.0 2011-12-02

First, almost does something interesting, check in.
