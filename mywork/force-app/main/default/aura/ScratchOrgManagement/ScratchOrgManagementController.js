({
  init : function(component, event, helper) {
    helper.init(component);
  },

  handleComboBoxChanges : function(component, event, helper) {
    var comboboxId = event.getParam('comboboxId');

    if (comboboxId === "instance-select") {
      var instanceId = event.getParam('newValue');
      helper.selectInstance(component, instanceId);
    } else if (comboboxId === "branch-select") {
      helper.validateNewBranchName(component);
    }
  },

  handleAuthChanges : function(component, event, helper) {
    var isAuthorized = event.getParam('isAuthorized');
    component.set('v.isInstanceAuthorized', isAuthorized);
  },

  logIntoScratch: function(component, event, helper) {
    event.preventDefault();
    var scratchOrgId = event.getSource().get('v.value');
    helper.logIntoScratch(component, scratchOrgId);
  },

  createScratch: function(component, event, helper) {
    helper.createScratch(component);
  },

  handlePlatformEvents: function(component, event, helper) {
    if (event.getParam("eventType") === component.get("v.SCRATCH_ORG_EVENT_NAME")) {
      var data = event.getParam("data");
      helper.handleScratchOrgEvent(component, data);
    }
  },

  commitChanges: function(component, event, helper) {
    event.preventDefault();
    var eventSourceId = event.target.id;
    var scratchOrgId = eventSourceId.slice(eventSourceId.indexOf("-") + 1);
    component.set('v.selectedScratchOrgId', scratchOrgId);
    document.getElementById('container-body').dataset.currentPage = 'scratch-org-commit';
    document.getElementById('alm-container').scrollIntoView();
  },

  handleNewBranchNameChange: function(component, event, helper) {
    helper.validateNewBranchName(component);
  }
})
