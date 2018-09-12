({
  init : function(component, event, helper) {
    helper.getConfig(component, $A.getCallback(function(errors, data) {
      if (errors) { throw "Could not retrieve the configuration from the server!"; }

      helper.initCometDStream(component, $A.getCallback(function(errors, data) {
        component.get('v.initialSubscriptionEventTypes').forEach(function(eventType) {
          helper.addEventSubscription(component, helper, eventType);
        });
      }));
    }));
  },

  addEventSubscription: function(component, event, helper) {
    const platformEventName = event.getParam('arguments').eventName;

    if (component.get("v.cometdInited")) {
      // if cometD is ready, add subscriptions right away.
      helper.addEventSubscription(component, helper, platformEventName);
    } else {
      // else add them to the list of initial subscriptions, which will be processed after init
      var initialSubscriptions = component.get("v.initialSubscriptionEventTypes");
      if (initialSubscriptions.indexOf(platformEventName) === -1) {
        initialSubscriptions.push(platformEventName);
        component.set("v.initialSubscriptionEventTypes", initialSubscriptions);
      }
    }
  }
})
