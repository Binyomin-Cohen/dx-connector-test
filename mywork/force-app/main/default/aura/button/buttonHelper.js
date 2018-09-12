({
  fireButtonEvent : function(component) {
    var appEvent = component.getEvent("buttonEvent");
    appEvent.setParams({ "actionType" : component.get("v.actionType") });
    appEvent.fire();
  }
});