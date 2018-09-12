({
  init : function(component, event, helper) {
    helper.init(component);
  },

  handleComboBoxChanges : function(component, event, helper) {
    var comboboxId = event.getParam('comboboxId'),
        commitRequest = component.get("v.commitRequest");

    if (comboboxId === "instance-select") {
      var instanceId = event.getParam('newValue');
      helper.selectInstance(component, instanceId);

    } else if (comboboxId === "repo-select") {
      var repoId = event.getParam('newValue');
      commitRequest.repositoryId = repoId;
      component.set("v.commitRequest", commitRequest);

    } else if (comboboxId === "branch-select") {
      var branchName = event.getParam('newValue');
      commitRequest.branchName = branchName;
      component.set("v.commitRequest", commitRequest);
    }
  },

  handleAuthChanges : function(component, event, helper) {
    var isAuthorized = event.getParam('isAuthorized');
    component.set('v.isInstanceAuthorized', isAuthorized);

    var state = component.get('v.state');

    if (state) {
      component.find('repo-select').setState(state);
      component.find('changes').setState(state);

      component.set('v.state', null);
    }
  },

  handleUnsavedPageChangeEvent : function(component, event, helper) {
    var isPageUpdated = event.getParam('isPageUpdated');
    //Item-04394 - addresses external scripts not being loaded quikly enough
    if (typeof BW !== 'undefined' && BW.AlmCommon) {
      BW.AlmCommon.setHasUnsavedChanges(isPageUpdated);
    } else {
      window.setTimeout(
        $A.getCallback(function() {
          if (typeof BW !== 'undefined' && BW.AlmCommon) {
            BW.AlmCommon.setHasUnsavedChanges(isPageUpdated);
          }
          else {
            var pageMessageAddEvent = $A.get('e.c:pageMessageAdd');
            pageMessageAddEvent.setParams({
              'type' : 'error',
              'message' : 'An error occurred while loading the page. Please try again or contact your administrator for assistance.'
            });
            pageMessageAddEvent.fire();
          }
        }), 5000);
    }
  },

  handleAuthInitEvent : function(component, event, helper) {
    var state = {};

    state.selectedInstanceId = component.find('instance-select').get('v.selectedValue');

    component.find('repo-select').getState(state);
    component.find('changes').getState(state);

    var savePageStateAction = component.get('c.savePageState');
    savePageStateAction.setParams({
      "backlogItemId" : component.get('v.recordId'),
      "pageStateMap" : state
    });
    $A.enqueueAction(savePageStateAction);
  }
})