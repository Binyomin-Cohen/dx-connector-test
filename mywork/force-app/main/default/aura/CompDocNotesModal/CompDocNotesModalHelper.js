({
  applyNotes : function(component, helper) {
    if (!component.get('v.enableApply')) {
      return;
    }

    var backlogComponentId = component.get('v.backlogComponentId'),
        noteValue = component.get('v.noteText').trim(),
        updateNotesAction = component.get('c.updateComponentNotes'),
        params = { backlogComponentId : backlogComponentId, notes : noteValue };

    updateNotesAction.setParams(params);
    updateNotesAction.setCallback(this, function(data) {
      var options = {};
      options.successCb = function() {
        helper.fireNotesModalEvent({
            modalType: "notes",
            action: "apply",
            payload: params
        });
      };
      BW.LTCommon.auraCallbackHandler(data, options);
    });
    $A.enqueueAction(updateNotesAction);
  },

  noteValueChange : function(component) {
    var NOTE_LENGTH_MAX = component.get('v.noteMaxLength') || 32768,
        noteLength = component.get('v.noteText').length;
    component.set('v.enableApply', true);
    component.set('v.noteLengthNotification', noteLength >= NOTE_LENGTH_MAX);
  },

  fireNotesModalEvent : function(params) {
      var evt = $A.get("e.c:modalEvent");
      evt.setParams(params);
      evt.fire();
  },

  closeModal : function(component) {
    this.fireNotesModalEvent({ modalType: "notes", action: "close" });
    component.set('v.noteName', '');
    component.set('v.noteText', '');
    component.set('v.backlogComponentId', '');
    component.set('v.enableApply', false);
    component.set('v.noteLengthNotification', false);
  }

});