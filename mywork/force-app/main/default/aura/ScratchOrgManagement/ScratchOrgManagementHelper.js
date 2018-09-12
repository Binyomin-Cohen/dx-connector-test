({
  init: function(component) {
    var self = this;

    component.set('v.newBranchName', component.get('v.backlogItemName'));

    var getInstances = component.get('c.getInstances');
    getInstances.setCallback(this, function(data) {
      var options = {};
      options.successCb = function() {
        var instances = data.getReturnValue();
        component.set('v.instances', instances.map(function(instance) {
          return {
            "label" : instance.Name,
            "value" : instance.Id
          };
        }));
      };
      BW.LTCommon.auraCallbackHandler(data, options);
    });
    $A.enqueueAction(getInstances);

    self.refreshScratchOrgs(component);

    var getDevHubOrg = component.get('c.getDevHubOrgId');
    getDevHubOrg.setCallback(this, function(data) {
      var options = {};
      options.successCb = function() {
        if (data && data.getReturnValue()) {
          var instanceId = data.getReturnValue();
          component.set('v.selectedInstanceId', instanceId);
        }
      };
      BW.LTCommon.auraCallbackHandler(data, options);
    });
    $A.enqueueAction(getDevHubOrg);
  },

  refreshScratchOrgs: function(component) {
    var getScratchOrgs = component.get('c.getScratchOrgs');
    getScratchOrgs.setParams({ backlogItemId : component.get('v.backlogItemId') });

    getScratchOrgs.setCallback(this, function(data) {
      var options = {};
      options.successCb = function() {
        var scratchOrgs = data.getReturnValue();
        component.set('v.scratchOrgs', scratchOrgs);
      };
      BW.LTCommon.auraCallbackHandler(data, options);
    });
    $A.enqueueAction(getScratchOrgs);
  },

  selectInstance: function(component, instanceId) {
    component.set('v.selectedInstanceId', instanceId);
    component.set('v.isAuthorized', false); //????
    var action = component.get('c.setDevHubOrg');
    action.setParams({devHubInstanceId: instanceId});
    //action.setCallback(this, function(data) {});
    $A.enqueueAction(action);
  },

  createScratch: function(component) {
    var repoSelect = component.find("repo-select"),
        repoSelectState = repoSelect.getState(),
        scratchOrgDefId = component.find('scratch-org-def-select').get('v.selectedScratchOrgDefId');
    
    var createActualScratchOrg = this.createActualScratchOrg;
    var action = component.get('c.createScratchOrgRecord');
    var scratchCustomName = component.get('v.newScratchOrgName');
    action.setParams({
      name: scratchCustomName,
      backlogItemId: component.get('v.backlogItemId'),
      vcRepositoryId: repoSelectState.selectedRepositoryId,
      repositoryLocation: component.get('v.createNewBranch') ? component.get('v.newBranchName'): repoSelectState.selectedBranch,
      scratchOrgDefId: scratchOrgDefId,
      durationDays: component.get('v.durationDays') ? component.get('v.durationDays'): 7,
      parentBranchName : component.get('v.createNewBranch') ? repoSelectState.selectedBranch : null
    });

    action.setCallback(this, function(data) {
      var options = {};
      options.successCb = function() {
        if (data && data.getReturnValue()) {
          var scratchOrgId = data.getReturnValue();
          createActualScratchOrg(component, scratchOrgId);
        }
      };
      BW.LTCommon.auraCallbackHandler(data, options);
    });
    $A.enqueueAction(action);
   },

  createActualScratchOrg: function(component, scratchOrgId) {
    var action = component.get('c.createScratchOrg');
    action.setParams({ scratchOrgId : scratchOrgId });
    action.setCallback(this, function(data) {
      var options = {};
      options.errorCb = function(errorMessage) {
        BW.LTCommon.addPageMessage("error", errorMessage);
      };
      BW.LTCommon.auraCallbackHandler(data, options);
    });
    $A.enqueueAction(action);
  },

  logIntoScratch: function( component, scratchOrgId){
    var action = component.get('c.getLoginUrlForScratchOrg');
    action.setParams({scratchOrgId: scratchOrgId});

    action.setCallback(this, function(data) {
      var options = {};
      options.successCb = function() {
        if (data && data.getReturnValue()) {
          var loginUrl = data.getReturnValue();
          window.open(loginUrl);
        }
      };
      BW.LTCommon.auraCallbackHandler(data, options);
    });

    $A.enqueueAction(action);
  },

  initScratchOrgEventStream: function(component) {
    component.find("scratch-org-event-stream").addEventSubscription(component.get('v.SCRATCH_ORG_EVENT_NAME'));
  },

  handleScratchOrgEvent: function(component, platformEventData) {
    var pageMessageAddEvent = $A.get("e.c:pageMessageAdd");

    const hasErrors = platformEventData.Has_Error__c || false;
    const type = platformEventData.Type__c;
    const eventMessage = platformEventData.Details__c;
    if (!eventMessage) { throw 'Received Scratch Org Event with no Details__c field' };

    pageMessageAddEvent.setParams({
      "type": hasErrors ? 'error' : 'success',
      "message": eventMessage
    });
    pageMessageAddEvent.fire();

    if (type === 'org created') {
      this.refreshScratchOrgs(component);
    }
  },

  validateNewBranchName: function(component) {
    var branches = component.find('repo-select').get('v.branches');
    var newBranchName = component.get('v.newBranchName');
    var newBranchInput = component.find('new-branch-name');

    if (branches.filter(
      function(branch){
        return branch.value.endsWith("/" + newBranchName);
      }).length > 0) {

        component.set('v.newBranchInvalid', true);
        
        newBranchInput.setCustomValidity('Branch already exists');
        newBranchInput.reportValidity();
    } else {
      component.set('v.newBranchInvalid', false);
      newBranchInput.setCustomValidity('');
      newBranchInput.reportValidity();
    }
  }
})
