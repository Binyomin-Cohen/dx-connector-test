({
  fireButtonEvent : function(component) {
    var appEvent = component.getEvent("buttonEvent");
    appEvent.setParams({ "actionType" : "handleSaveRepository" });
    appEvent.fire();
  }
})
