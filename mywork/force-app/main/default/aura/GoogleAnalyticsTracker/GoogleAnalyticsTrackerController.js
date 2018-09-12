({
  doInit : function(component, event, helper) {
    helper.init(component);
  },

  handleTrackingEvent : function(component, event, helper) {
    var message = {
      "category" : event.getParam("category"),
      "action" : event.getParam("action"),
      "label" : event.getParam("label"),
      "value" : event.getParam("value"),
    };

    var vfWindow = component.find("ga-frame").getElement().contentWindow;
    vfWindow.postMessage(message, component.get('v.vfDomain'));
  }


});