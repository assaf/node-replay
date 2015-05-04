const debug = require('./debug');
const URL   = require('url');


// Simple proxy that spits all request URLs to the console if the debug settings is true.
//
// Example
//   replay.use replay.logger(exports)
module.exports = function logger() {
  return function(request, callback) {
    debug(`Requesting ${request.method} ${URL.format(request.url)}`);
    request.on('response', function(response) {
      debug(`Received ${response.statusCode} ${URL.format(request.url)}`);
    });
    request.on('error', function(error) {
      debug(`Error ${error}`);
    });
    callback();
  };
};


