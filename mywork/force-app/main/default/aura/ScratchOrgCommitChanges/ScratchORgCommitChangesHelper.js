({
  init: function(component) {
    var commitRequest = component.get("v.commitRequest") || {};
    component.set("v.commitRequest", {
      repositoryId: commitRequest.repositoryId || "",
      branchName: commitRequest.branchName || "",
      commitMessage: commitRequest.commitMessage || "",
      instanceId: component.get('v.recordId')
    });
  },

  selectInstance: function(component, instanceId) {
    component.set('v.selectedInstanceId', instanceId);
    component.set('v.isAuthorized', false);

    var commitRequest = component.get("v.commitRequest");
    commitRequest.instanceId = instanceId;
    component.set("v.commitRequest", commitRequest);
  },

  sendDxGitDiffRequest: function(component, helper) {
    component.set('v.isFindingModifiedComps', true);
    var dxGitDiffRequest = component.get('c.sendDxGitDiffRequest');
    dxGitDiffRequest.setParams({
      scratchOrgId: component.get('v.recordId'),
      vcRepoId: component.get('v.commitRequest').repositoryId,
      branch: component.get('v.commitRequest').branchName
    });

    dxGitDiffRequest.setCallback(this, function(data) {
      var options = {};
      options.successCb = function() {
        var pageMessageAddEvent = $A.get("e.c:pageMessageAdd");
        pageMessageAddEvent.setParams({"type": 'success', "message": "Finding Modified Components"});
        pageMessageAddEvent.fire();
      };
      BW.LTCommon.auraCallbackHandler(data, options);
    });
    $A.enqueueAction(dxGitDiffRequest);
  },

  sendDxGitCommitRequest: function(component, helper) {
    var dxGitCommitRequest = component.get('c.sendDxGitCommitRequest');
    var selectedPaths = helper.findSelectedComponentRows(component);

    dxGitCommitRequest.setParams({
      scratchOrgId: component.get('v.recordId'),
      vcRepoId: component.get('v.commitRequest').repositoryId,
      branch: component.get('v.commitRequest').branchName,
      componentPaths: selectedPaths,
      commitMessage: component.get('v.commitMessage')
    })

    dxGitCommitRequest.setCallback(this, function(data) {
      var options = {};
      options.successCb = function() {
        var pageMessageAddEvent = $A.get("e.c:pageMessageAdd");
        pageMessageAddEvent.setParams({"type": 'success', "message": "Committing Selected Components"});
        pageMessageAddEvent.fire();
      };
      BW.LTCommon.auraCallbackHandler(data, options);
    });
    $A.enqueueAction(dxGitCommitRequest);
  },

  findSelectedComponentRows: function(component) {
    var checkboxes = component.find("diff-checkboxes") || [];
    if (checkboxes.length > 0) {
      return checkboxes.filter(function(checkbox) {return checkbox.isChecked();})
                       .map(function(checkbox) {return checkbox.getElement().parentElement.dataset.selectedPath});
    } else if (!Array.isArray(checkboxes)) { // If there's only one element found, SF changes the element, not as a list
      return [checkboxes.getElement().parentElement.dataset.selectedPath];
    } else {
      return [];
    }
  },

  checkIfChangesAreCommitable: function(component, event, helper) {
    var selectedComponents = helper.findSelectedComponentRows(component);
    component.set('v.changesAreCommittable',
      selectedComponents.length > 0 && component.get('v.commitMessage')
      && component.get('v.commitRequest.repositoryId') && component.get('v.commitRequest.branchName')
    );
  },

  handleRecordIdChange: function(component) {
    var dxGetScratchRequest = component.get('c.getScratchOrgById');
    dxGetScratchRequest.setParams({
      scratchOrgId: component.get('v.recordId')
    });

    dxGetScratchRequest.setCallback(this, function(data){
      var options = {};
      options.successCb = function() {
        var returnVal = data.getReturnValue();
        var repoSelect = component.find('commit-repo-select');
        console.log('repo is ' + returnVal.VC_Repository__c);
        repoSelect.selectRepo(returnVal.VC_Repository__c);
        repoSelect.set('v.selectedBranch', returnVal.Repository_Location__c)
      };
      BW.LTCommon.auraCallbackHandler(data, options);
    });
    $A.enqueueAction(dxGetScratchRequest);

  }
});
