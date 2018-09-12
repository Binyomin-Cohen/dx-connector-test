/**
* Eases the pain of separating pure API from testOnly functions
*/
(function(global) {

  // Bind polyfill for PhantomJS
  // @see https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Function/bind
  if (!Function.prototype.bind) {
    Function.prototype.bind = function(oThis) {
      if (typeof this !== 'function') {
        // closest thing possible to the ECMAScript 5
        // internal IsCallable function
        throw new TypeError('Function.prototype.bind - what is trying to be bound is not callable');
      }

      var aArgs   = Array.prototype.slice.call(arguments, 1),
          fToBind = this,
          fNOP    = function() {},
          fBound  = function() {
            return fToBind.apply(this instanceof fNOP
                   ? this
                   : oThis,
                   aArgs.concat(Array.prototype.slice.call(arguments)));
          };

      fNOP.prototype = this.prototype;
      fBound.prototype = new fNOP();

      return fBound;
    };
  }

  /**
  * @constructor
  * @param opts
  * @param opts.pure - The methods in the pure API (actually used on the module)
  * @param opts.testOnly - The methods that are exposed only within a test context
  */
  function ApiBuilder(opts) {
    this.pureApi = {};
    this.testOnlyApi = {};
    this.opts = opts || {};
    this.loadApi();
  }

  ApiBuilder.prototype = {

    /**
    * Returns true if the ApiBuilder is within a test context
    * @private
    * @return {bool}
    */
    isTesting: function() {
      return typeof window.__karma__ !== 'undefined';
    },

    /**
    * Loads the API from the pure and testOnly options
    * @private
    */
    loadApi: function() {
      if(this.opts.pure) {
        Object.keys(this.opts.pure).forEach(function(funcName) {
          this.setPure(funcName, this.opts.pure[funcName]);
        }.bind(this));
      }
      if(this.opts.testOnly) {
        Object.keys(this.opts.testOnly).forEach(function(funcName) {
          if(!this.testOnlyApi[funcName]) {
            this.setTestOnly(funcName, this.opts.testOnly[funcName]);
          }
        }.bind(this));
      }
    },

    /**
    * Checks for duplicate method declarations and throws an exception if one exists
    * @private
    */
    throwIfExists: function(name) {
      if(this.testOnlyApi[name]) {
        throw new Error('Duplicate API method: ' + name);
      }
    },

    /**
    * Adds a new pure function to the API
    * @param {string} name
    * @param {function} func
    */
    setPure: function(name, func) {
      this.throwIfExists(name);
      this.pureApi[name] = func;
      this.setTestOnly(name, func);
    },

    /**
    * Adds a new test only function to the API
    * @param {string} name
    * @param {function} func
    */
    setTestOnly: function(name, func) {
      this.throwIfExists(name);
      this.testOnlyApi[name] = func;
    },

    /**
    * Returns the correct API based on the running context
    * @return {object}
    */
    getApi: function() {
      if(!this.isTesting()) {
        return this.pureApi;
      } else {
        return this.testOnlyApi;
      }
    }
  };

  var init = function() {
    return ApiBuilder;
  };

  
  if (typeof define === "function") {
    define([], function() {
      return init();
    });
  } else {
    var API = init();
    global.BW = global.BW || {};
    global.BW.ApiBuilder = API;
    return API;
  }

})(this);