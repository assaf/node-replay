module.exports = class Chain {

  append(proxy) {
    const fallback = this._fallback(proxy);
    this.first  = this.first || fallback;
    if (this.last)
      this.last.next = fallback;
    this.last   = fallback;
    return this;
  }

  prepend(proxy) {
    const fallback = this._fallback(proxy);
    fallback.next = this.first;
    this.first = fallback;
    this.last  = this.last || fallback;
    return this;
  }

  _fallback(proxy) {
    function fallback(request, callback) {
      proxy(request, function(error, response) {
        if (error || response)
          callback(error, response);
        else if (fallback.next)
          fallback.next(request, callback);
        else
          callback();
      });
    }
    return fallback;
  }

  clear() {
    this.first = this.last = null;
  }

  get start() {
    return this.first;
  }

};

