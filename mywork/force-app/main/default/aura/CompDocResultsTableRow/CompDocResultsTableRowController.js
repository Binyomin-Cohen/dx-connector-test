({
  init : function(component, event, helper){
    helper.initHandler(component);
  },

  handleDeployManuallyChange : function(component, event, helper) {
    helper.updateDeployManually(component, event);
  },

  handleCheckboxClick : function(component, event, helper) {
    var evt = component.getEvent("rowSelectEvent");
    evt.setParam("rowId", component.get('v.componentRecord').backlogComponent.Id);
    evt.fire();
  },

  handleDisplayNoteModal : function(component, event, helper) {
    helper.displayNoteModal(component);
  }
});
