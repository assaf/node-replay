// The Replay module holds global configution properties and methods.


const Catalog           = require('./catalog');
const Chain             = require('./chain');
const debug             = require('./debug');
const { EventEmitter }  = require('events');
const logger            = require('./logger');
const passThrough       = require('./pass_through');
const recorder          = require('./recorder');


// Supported modes.
const MODES = [ 'bloody', 'cheat', 'record', 'replay' ];

// Headers that are recorded/matched during replay.
const MATCH_HEADERS = [ /^accept/, /^authorization/, /^body/, /^content-type/, /^host/, /^if-/, /^x-/ ];


// Instance properties:
//
// catalog   - The catalog is responsible for loading pre-recorded responses
//             into memory, from where they can be replayed, and storing captured responses.
//
// chain     - The proxy chain.  Essentially an array of proxies through which
//             each request goes, from first to last.  You generally don't need
//             to use this unless you decide to reconstruct your own chain.
//
//             When adding new proxies, you probably want those executing ahead
//             of any existing proxies (certainly the pass-through proxy), so
//             you'll want to prepend them.  The `use` method will prepend a
//             proxy to the chain.
//
// headers   - Only these headers are matched when recording/replaying.  A list
//             of regular expressions.
//
// fixtures  - Main directory for replay fixtures.
//
// mode      - The mode we're running in, one of:
//   bloody  - Allow outbound HTTP requests, don't replay anything.  Use this to
//             test your code against changes to 3rd party API.
//   cheat   - Allow outbound HTTP requests, replay captured responses.  This
//             mode is particularly useful when new code makes new requests, but
//             unstable yet and you don't want these requests saved.
//   record  - Allow outbound HTTP requests, capture responses for future
//             replay.  This mode allows you to capture and record new requests,
//             e.g. when adding tests or making code changes.
//   replay  - Do not allow outbound HTTP requests, replay captured responses.
//             This is the default mode and the one most useful for running tests
class Replay extends EventEmitter {

  constructor(mode) {
    super();
    if (!~MODES.indexOf(mode))
      throw new Error(`Unsupported mode '${mode}', must be one of ${MODES.join(', ')}.`);

    this.chain  = new Chain();
    this.mode   = mode;
    // Localhost servers: pass request to localhost
    this._localhosts = {
      'localhost': true,
      '127.0.0.1': true
    };
    // Pass through requests to these servers
    this._passThrough = { };
    // Dropp connections to these servers
    this._dropped = { };
    this.catalog = new Catalog(this);
    this.headers = MATCH_HEADERS;

    // Automatically emit connection errors and such, also prevent process from failing.
    this.on('error', function(error) {
      debug(`Replay: ${error.message || error}`);
    });
  }


  // Addes a proxy to the beginning of the processing chain, so it executes ahead of any existing proxy.
  //
  // Example
  //     replay.use replay.logger()
  use(proxy) {
    this.chain.prepend(proxy);
    return this;
  }

  // Pass through all requests to these hosts
  passThrough(...hosts) {
    this.reset(...hosts);
    for (let host of hosts)
      this._passThrough[host] = true;
    return this;
  }

  // True to pass through requests to this host
  isPassThrough(host) {
    const domain = host.replace(/^[^.]+/, '*');
    return !!(this._passThrough[host] || this._passThrough[domain] || this._passThrough[`*.${host}`]);
  }

  // Do not allow network access to these hosts (drop connection)
  drop(...hosts) {
    this.reset(...hosts);
    for (let host of hosts)
      this._dropped[host] = true;
    return this;
  }

  // True if this host is on the dropped list
  isDropped(host) {
    const domain = host.replace(/^[^.]+/, '*');
    return !!(this._dropped[host] || this._dropped[domain] || this._dropped[`*.${host}`]);
  }

  // Treats this host as localhost: requests are routed directly to 127.0.0.1, no
  // replay.  Useful when you want to send requests to the test server using its
  // production host name.
  localhost(...hosts) {
    this.reset(...hosts);
    for (let host of hosts)
      this._localhosts[host] = true;
    return this;
  }

  // True if this host should be treated as localhost.
  isLocalhost(host) {
    const domain = host.replace(/^[^.]+/, '*');
    return !!(this._localhosts[host] || this._localhosts[domain] || this._localhosts[`*.${host}`]);
  }

  // Use this when you want to exclude host from dropped/pass-through/localhost
  reset(...hosts) {
    for (let host of hosts) {
      delete this._localhosts[host];
      delete this._passThrough[host];
      delete this._dropped[host];
    }
    return this;
  }

  get fixtures() {
    return this.catalog.getFixturesDir();
  }

  set fixtures(dir) {
    // Clears loaded fixtures, and updates to new dir
    this.catalog.setFixturesDir(dir);
  }

}


const replay = new Replay(process.env.REPLAY || 'replay');


// The default processing chain (from first to last):
// - Pass through requests to localhost
// - Log request to console is `deubg` is true
// - Replay recorded responses
// - Pass through requests in bloody and cheat modes
function passWhenBloodyOrCheat(request) {
  return replay.isPassThrough(request.url.hostname) ||
         (replay.mode === 'cheat' && !replay.isDropped(request.url.hostname));
}

function passToLocalhost(request) {
  return replay.isLocalhost(request.url.hostname) ||
         replay.mode === 'bloody';
}

replay
  .use(passThrough(passWhenBloodyOrCheat))
  .use(recorder(replay))
  .use(logger(replay))
  .use(passThrough(passToLocalhost));


module.exports = replay;

require('./patch_http_request');
require('./patch_dns_lookup');


