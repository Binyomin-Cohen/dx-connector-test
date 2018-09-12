({
  init : function(component) {
    component.set('v.commitMessagePlaceHolder',
        '1) Provide the backlog item key first on its own line to have the commit linked to the backlog item in Sightline\n' +
        '2) Provide a detailed summary, what has changed, and why it was changed for traceability\n\n' +
        'Example:\n' +
        'Item-99999 - Update the XYZ workflow rule to send email alerts to lead sales director.\n\n' +
        '  * Update the email address recipients on the email alert ZZZ to include the email address jon.doe@company.com.\n' +
        '  * This gets around the missing communications issue for the manager.'
    );
    component.set('v.commitMessage', component.get('v.commitMessagePlaceHolder'));
    component.set('v.excludeColumns', {
      notes : true,
      deployManually : true
    });
  },

  toggleCommitMessagePlaceholder : function(component) {
    if (component.get('v.commitMessagePlaceHolder') === component.get('v.commitMessage')) {
      component.set('v.commitMessage', '');
      component.set('v.containsPlaceholder', '');
    } else if (component.get('v.commitMessage') === '') {
      component.set('v.commitMessage', component.get('v.commitMessagePlaceHolder'));
      component.set('v.containsPlaceholder', 'contains-placeholder');
    } else {
      component.set('v.containsPlaceholder', '');
    }
  },

  handleCommitMessage: function(component, event) {
    var commitMessage = event.getSource().get("v.value"),
        commitRequest = component.get("v.commitRequest");

    commitRequest.commitMessage = commitMessage;
    component.set("v.commitRequest", commitRequest);
    this.fireUnsavedChangesEvent(component, true)
  },

  handleCommitButtonToggle: function(component) {
    var commitRequest = component.get("v.commitRequest");
    var disable = true;

    if (this.confirmValidString(commitRequest.backlogItemId) &&
        this.confirmValidString(commitRequest.repositoryId) &&
        this.confirmValidString(commitRequest.branchName) &&
        this.confirmValidString(commitRequest.instanceId) &&
        this.confirmValidString(commitRequest.commitMessage) &&
        (commitRequest.backlogComponentIds.length > 0) ) {
      disable = false;
    }

    component.set("v.disableCommitButton", disable);
  },

  handleSelectedBacklogComponentIdsChange: function(component, event, helper) {
    var backlogComponentIds = component.get("v.selectedBacklogComponentIds"),
        commitRequest = component.get("v.commitRequest");
    commitRequest['backlogComponentIds'] = backlogComponentIds;
    component.set("v.commitRequest", commitRequest);

    this.fireUnsavedChangesEvent(component, true)
  },

  makeCommitRequest: function(component, vcCommitId) {
    var action = component.get("c.makeCommitRequest"),
      self = this;

    action.setParams({
      vcCommitId: vcCommitId
    });

    action.setCallback(this, function(data) {
      var options = {};
      options.successCb = function() {
        var pageMessage = data.getReturnValue();
        BW.LTCommon.addPageMessage("success",
            pageMessage.message,
            "/"+vcCommitId,
            "Click here for the status of your commit or to see any commit errors.",
            "Click here",
            " for the status of your commit or to see any commit errors.");

        var expirePageStateAction = component.get('c.expirePageState');
        expirePageStateAction.setParams({
          "backlogItemId" : component.get('v.backlogItemId')
        });
        $A.enqueueAction(expirePageStateAction);
      };

      options.errorCb = function(errorMessage) {
        BW.LTCommon.addPageMessage("error", errorMessage);
      };

      options.cb = function() {
        self.resetButtonAndScrollToTop(component);
        self.fireUnsavedChangesEvent(component, false)
      };

      BW.LTCommon.auraCallbackHandler(data, options);
    });
    $A.enqueueAction(action);
  },

  commitChanges: function(component, event) {
    var commitRequest = component.get("v.commitRequest"),
        action = component.get("c.saveCommitRequest"),
        self = this;

    $A.get('e.c:pageMessagesClear').fire();

    component.set('v.disableCommitButton', true);
    component.set('v.commitInProgress', true);

    action.setParams({
      commitRequestJSON: JSON.stringify(commitRequest)
    });

    // Save the commit request, then call makeCommitRequest with the returned Id
    action.setCallback(this, function(data) {
      var options = {};
      options.successCb = function() {
        var vcCommitId = data.getReturnValue();
        self.makeCommitRequest(component, vcCommitId);
      };

      options.errorCb = function(errorMessage) {
        BW.LTCommon.addPageMessage("error", errorMessage);
        self.resetButtonAndScrollToTop(component);
      };

      BW.LTCommon.auraCallbackHandler(data, options);

    });
    $A.enqueueAction(action);
  },

  resetButtonAndScrollToTop: function(component) {
    component.set("v.commitInProgress", false);
    $('html,body').scrollTop(0);
  },

  confirmValidString: function(value) {
    if (!value) {
      return false;
    } else if (value.length === 0 || (/^\s+$/.test(value))) {
      return false;
    } else {
      return true;
    }
  },

  fireUnsavedChangesEvent : function(component, isUpdated) {
    var evt = component.getEvent("unsavedPageEvent");
    evt.setParam("isPageUpdated", isUpdated);
    evt.fire();
  },

  getState : function(component, state) {
    state.selectedBacklogComponentIds = component.get('v.selectedBacklogComponentIds');
    state.commitMessage = component.get('v.commitRequest').commitMessage;
  },

  setState : function(component, state) {
    if (BW.AlmCommon.getProperty(state, 'selectedBacklogComponentIds')) {
      component.set('v.selectedBacklogComponentIds', state.selectedBacklogComponentIds);
    }

    if (BW.AlmCommon.getProperty(state, 'commitMessage')) {
      component.set('v.commitMessage', state.commitMessage);
      this.toggleCommitMessagePlaceholder(component);

      var commitRequest = component.get('v.commitRequest');
      commitRequest.commitMessage = state.commitMessage;
      component.set('v.commitRequest', commitRequest);
    }
  }

});
