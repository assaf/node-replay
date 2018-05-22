// Patch HTTP.request to make all request go through Replay
//
// Patch based on io.js, may not work with Node.js

const HTTP          = require('http');
const HTTPS         = require('https');
const ProxyRequest  = require('./proxy');
const Replay        = require('./');
const URL           = require('url');


// Route HTTP requests to our little helper.
HTTP.request = function(options, callback) {
  if (typeof options === 'string' || options instanceof String)
    options = URL.parse(options);

  // WebSocket request: pass through to Node.js library
  if (options.headers && options.headers.Upgrade === 'websocket')
    return new HTTP.ClientRequest(options, callback);

  const hostname = options.hostname || (options.host && options.host.split(':')[0]) || 'localhost';
  if (Replay.isLocalhost(hostname) || Replay.isPassThrough(hostname))
    return new HTTP.ClientRequest(options, callback);

  // Proxy request
  const request = new ProxyRequest(options, Replay.chain.start);
  if (callback)
    request.once('response', callback);
  return request;
};


// Patch .get method otherwise it calls original HTTP.request
HTTP.get = function(options, cb) {
  const req = HTTP.request(options, cb);
  req.end();
  return req;
}


HTTPS.get = HTTP.get;

