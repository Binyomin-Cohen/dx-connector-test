({
  handleApplyNotesEvent : function(component, event, helper) {
    helper.applyNotes(component, helper);
  },
  handleNoteValueChange : function(component, event, helper) {
    helper.noteValueChange(component);
  },
  handleCloseModalEvent : function(component, event, helper) {
    helper.closeModal(component);
  }
});