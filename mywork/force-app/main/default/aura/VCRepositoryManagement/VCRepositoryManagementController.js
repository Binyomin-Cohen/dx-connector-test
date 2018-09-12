({

  doInit : function(component, event, helper) {
    helper.init(component);
  },

  handleCancelEditMode : function(component, event, helper) {
    helper.fireClearRepoSelectEvent();
  },

  setUnsavedChanges : function(component, event, helper) {
    helper.setUnsavedChanges(component, event);
  },

  updateSourceFormat: function(component, event, helper) {
    helper.updateSourceFormat(component, event, helper);
  },

  handleButtonClick : function(component, event, helper) {
    var actionType = event.getParam("actionType");
    if (actionType === "handleSaveRepository") {
      helper.clearPageMessages();
      helper.updateSourceFormat(component, event, helper);
      helper.upsertRepository(component);
    } else if (actionType === "handleCreateNewRepo") {
      var url = BW.LTCommon.buildNamespaceFriendlyUrl("/apex/AdminVersionControl?id=new", component.get('v.namespace'));
      BW.AlmCommon.navigateTo(url);
    }
  },

  handleEnableExternalCommitClick : function (component, event, helper) {
    var externalCommitEnabled = event.target.checked;
    component.set('v.selectedRepo.enableExternalCommitLink', externalCommitEnabled);
    if (!externalCommitEnabled) {
      component.set('v.selectedRepo.host', '');
      component.set('v.selectedRepo.orgName', null);
    }
    helper.setUnsavedChanges(component, event);
  }

});
