({
  init : function(component, event, helper) {
    helper.init(component);
  },

  handleComboBoxChanges : function(component, event, helper) {
    var comboboxId = event.getParam('comboboxId');

    if (comboboxId === "scratch-def-select") {
      var scratchDefId = event.getParam('newValue');
      component.set('v.selectedScratchOrgDefId', scratchDefId);
      helper.setTemplateLinkUrl(component, scratchDefId);
    } 
  },
})
