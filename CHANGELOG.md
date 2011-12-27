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
