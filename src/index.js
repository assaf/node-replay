const DNS           = require('dns');
const HTTP          = require('http');
const HTTPS         = require('https');
const ProxyRequest  = require('./proxy');
const Replay        = require('./replay');
const URL           = require('url');


const httpRequest   = HTTP.request;
const httpsRequest  = HTTPS.request;


// Route HTTP requests to our little helper.
HTTP.request = function(options, callback) {
  if (typeof options === 'string' || options instanceof String)
    options = URL.parse(options);

  // WebSocket request: pass through to Node.js library
  if (options.headers && options.headers.Upgrade === 'websocket')
    return httpRequest(options, callback);

  const hostname = options.hostname || (options.host && options.host.split(':')[0]) || 'localhost';
  if (Replay.isLocalhost(hostname) || Replay.isPassThrough(hostname))
    return httpRequest(options, callback);

  // Proxy request
  const request = new ProxyRequest(options, Replay.chain.start);
  if (callback)
    request.once('response', callback);
  return request;
};


// HTTP.get is shortcut for HTTP.request
HTTP.get = function(options, callback) {
  const request = HTTP.request(options, callback);
  request.end();
  return request;
};


// Route HTTPS requests
HTTPS.request = function(options, callback) {
  if (typeof options === 'string' || options instanceof String)
    options = URL.parse(options);

  // WebSocket request: pass through to Node.js library
  if (options.headers && options.headers.Upgrade === 'websocket')
    return httpsRequest(options, callback);

  const hostname = options.hostname || (options.host && options.host.split(':')[0]) || 'localhost';
  if (Replay.isLocalhost(hostname) || Replay.isPassThrough(hostname))
    return httpsRequest(options, callback);

  // Proxy request
  const httpsOptions = Object.assign({ }, options);
  httpsOptions.protocol = 'https:';
  const request = new ProxyRequest(httpsOptions, Replay.chain.start);
  if (callback)
    request.once('response', callback);
  return request;
};


// HTTPS.get is shortcut for HTTPS.request
HTTPS.get = function(options, callback) {
  const request = HTTPS.request(options, callback);
  request.end();
  return request;
};


// Redirect HTTP requests to 127.0.0.1 for all hosts defined as localhost
const originalLookup = DNS.lookup;
DNS.lookup = function(domain, options, callback) {
  let family;
  if (typeof options === 'function') {
    [family, callback] = [4, options];
    options = family;
  } else if (typeof options === 'object')
    family = options.family;
  else
    family = options;

  if (Replay.isLocalhost(domain)) {
    // io.js options is an object, Node 0.10 family number
    const ip = (family === 6) ? '::1' : '127.0.0.1';
    callback(null, ip, family);
  } else
    originalLookup(domain, options, callback);
};


module.exports = Replay;

