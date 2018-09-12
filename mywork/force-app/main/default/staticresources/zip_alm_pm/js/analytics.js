(function(global) {

  var init = function() {
     /**
     * Log an event to google analytics
     * @param category {String}
     * @param action  {String}
     * @param label   {String} an optional label describing the event
     * @param value   {Number} an optional integer value
     */
    function trackEvent(category, action, label, value) {
      if (global.ga) {
        var eventData = {
          'hitType': 'event',
          'eventCategory': category,
          'eventAction': action,
        };

        if (label) {
          eventData.eventLabel = label;
        }
        if (value) {
          eventData.eventValue = value;
        }
        global.ga('send', eventData);
      }
    }

    function addPostMessageListener() {
      global.addEventListener("message", function(event) {
        var allowedDomain = ".force.com";
        //check if domain ends with .force.com
        if (!event || event.origin.lastIndexOf(allowedDomain) !== event.origin.length - allowedDomain.length) {
          //unexpected origin
          return;
        }

        var data = event.data;
        trackEvent(data.category, data.action, data.label, data.value);
      });
    }

    var api = {
      trackEvent : trackEvent,
      addPostMessageListener : addPostMessageListener
    }
    return api;
  };

  if (typeof define === "function") {
    define([], function() {
      return init();
    });
  } else {
    var API = init();
    global.BW = global.BW || {};
    global.BW.Analytics = API;
    return API;
  }

})(this);