({
  init : function(component, event, helper) {
    helper.init(component);
  },

  handleComboBoxChanges : function(component, event, helper) {
    var comboboxId = event.getParam('comboboxId'),
        commitRequest = component.get("v.commitRequest");

    if (comboboxId === component.get('v.repoSelectComboboxId')) {
      var repoId = event.getParam('newValue');
      commitRequest.repositoryId = repoId;
      component.set("v.commitRequest", commitRequest);

    } else if (comboboxId === component.get('v.branchSelectComboboxId')) {
      var branchName = event.getParam('newValue');
      commitRequest.branchName = branchName;
      component.set("v.commitRequest", commitRequest);
    }
    helper.checkIfChangesAreCommitable(component, event, helper);
  },

  handleButtonClick: function(component, event, helper) {
    switch(event.getParam("actionType")) {
      case component.get('v.FIND_MODIFIED_COMPONENTS_ACTION_TYPE'):
        component.set('v.dxGitDiffResponse', {});
        helper.sendDxGitDiffRequest(component, helper);
        break;
      case component.get('v.COMMIT_MODIFIED_COMPONENTS_ACTION_TYPE'):
        helper.sendDxGitCommitRequest(component, helper);
        break;
    }
  },

  handlePlatformEvents: function(component, event, helper) {
    if (event.getParam("eventType") !== component.get("v.SCRATCH_ORG_EVENT_NAME")) { return; }

    var data = event.getParam("data");
    switch(data.Type__c) {
      case component.get('v.DIFF_COMPLETE_EVENT_TYPE'):
        var diff = JSON.parse(data.Details__c);
        if (diff.isSuccess) {
          component.set('v.dxGitDiffResponse', diff);
          component.set('v.isFindingModifiedComps', false);
        } else {
          var pageMessageAddEvent = $A.get("e.c:pageMessageAdd");
          pageMessageAddEvent.setParams({"type": 'error', "message": diff.errorMessage});
          pageMessageAddEvent.fire();
        }
        break;

      case component.get('v.COMMIT_COMPLETE_EVENT_TYPE'):
        var pageMessageAddEvent = $A.get("e.c:pageMessageAdd");
        pageMessageAddEvent.setParams({"type": 'success', "message": data.Details__c});
        pageMessageAddEvent.fire();
        break;
    };
  },

  checkIfChangesAreCommitable: function(component, event, helper) {
    helper.checkIfChangesAreCommitable(component, event, helper);
  },

  recordIdChange: function(component, event, helper) {
    helper.handleRecordIdChange(component);
  }
})
