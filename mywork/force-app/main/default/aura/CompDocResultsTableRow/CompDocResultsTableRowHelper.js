({
  initHandler : function(component){
    var componentNotes = component.get('v.componentRecord.notes');
    if (componentNotes){
      component.set('v.componentRecordNotes', componentNotes.substring(0, 108));
    }
  },

  updateDeployManually : function(component, event) {
    var deployManually = (true === event.target.checked);
    var updateAction = component.get("c.updateComponentDeployManually");

    updateAction.setParams({
      backlogComponentId: component.get("v.componentRecord.backlogComponent.Id"),
      deployManually: deployManually
    });

    updateAction.setCallback(this, function(data) {
      component.set('v.componentRecord.deployManually', deployManually);
      BW.LTCommon.auraCallbackHandler(data);
    });

    $A.enqueueAction(updateAction);
  },

  displayNoteModal : function(component) {
    var evt = $A.get("e.c:modalEvent"),
        modalParams = {
      modalType: "notes",
      action: "open",
      payload: component.get('v.componentRecord')
    };
    evt.setParams(modalParams);
    evt.fire();
  }
});
