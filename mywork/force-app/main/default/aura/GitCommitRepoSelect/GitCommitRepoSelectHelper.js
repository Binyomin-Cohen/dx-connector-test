({
  addPageMessage : function(type, message) {
    var pageMessageAddEvent = $A.get('e.c:pageMessageAdd');
    pageMessageAddEvent.setParams({
      'type' : type,
      'message' : message
    });
    pageMessageAddEvent.fire();
  },

  populateAvailableRepos : function(component) {
    var retrieveReposAction = component.get("c.retrieveRepos");
    retrieveReposAction.setParams({});

    var self = this;

    retrieveReposAction.setCallback(this, function(data) {
      var options = {};
      options.successCb = function() {
        var repoData = data.getReturnValue();
        var repoMapping = {};
        var selectOptions = repoData.map(function(repo) {
          repoMapping[repo.id] = repo.repoURL;
          return {
            label : repo.name,
            value : repo.id
          }
        });

          component.set('v.repositories', selectOptions);
          component.set('v.repositoryMapping', repoMapping);
      };

      options.errorCb = function(errorMessage) {
        self.addPageMessage("error", errorMessage);
      };

      BW.LTCommon.auraCallbackHandler(data, options);
    });

    $A.enqueueAction(retrieveReposAction);
  },

  selectRepo : function(component, repoId) {
    var retrieveBranchesAction = component.get("c.retrieveBranches");
    var branchesData = component.get('v.branchesData') || {};
    var self = this;

    component.set('v.repositoryHoverText', component.get('v.repositoryMapping')[repoId]);
    component.set('v.selectedRepositoryId', repoId);
    component.set('v.selectedBranch', '');
    this.fireUnsavedChangesEvent(component);

    if (!repoId || branchesData.hasOwnProperty(repoId)) {
      component.set('v.branches', branchesData[repoId]);
      return;
    }

    retrieveBranchesAction.setParams({
      "repositoryId" : repoId
    });

    retrieveBranchesAction.setCallback(this, function(data) {
      var options = {
        successCb : function() {
          var branches = data.getReturnValue() || [];
          var branchOptions = branches.map(function(branch) {
            return {
              label : branch,
              value : branch
            };
          });
      
          branchesData[repoId] = branchOptions;
          component.set('v.branches', branchOptions);
          component.set('v.branchesData', branchesData);

          if (component.get('v.savedBranch')) {
            component.find('branch-select').setValue(component.get('v.savedBranch'));
          }
        },

        errorCb : function(errorMessage) {
          self.addPageMessage("error", errorMessage);
        }
      };

      BW.LTCommon.auraCallbackHandler(data, options);
    });
    $A.enqueueAction(retrieveBranchesAction);
  },

  selectBranch : function(component, branchName) {
    component.set('v.selectedBranch', branchName);
    this.fireUnsavedChangesEvent(component);
  },

  fireUnsavedChangesEvent : function(component) {
    var evt = component.getEvent("unsavedPageEvent");
    evt.setParam("isPageUpdated", true);
    evt.fire();
  },

  getState : function(component, state) {
    state = state || {};
    state.selectedRepositoryId = component.find('repo-select').get('v.selectedValue');
    state.selectedBranch = component.find('branch-select').get('v.selectedValue');
    return state;
  },

  setState : function(component, state) {
    if (BW.AlmCommon.getProperty(state, 'selectedRepositoryId')) {
      component.find('repo-select').setValue(state.selectedRepositoryId);
    }

    if (BW.AlmCommon.getProperty(state, 'selectedBranch')) {
      component.set('v.savedBranch', state.selectedBranch);
    }
  }
});