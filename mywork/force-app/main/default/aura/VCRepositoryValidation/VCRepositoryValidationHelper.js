({
    addPageMessage : function(type, message) {
    var pageMessageAddEvent = $A.get('e.c:pageMessageAdd');
    pageMessageAddEvent.setParams({
      'type' : type,
      'message' : message
    });
    pageMessageAddEvent.fire();
  },

  clearPageMessages : function(type, message) {
    $A.get('e.c:pageMessagesClear').fire();
  },

  refreshVCRecord : function (component) {
    var action = component.get('c.loadVCRepoWithValidationsForUser');
    var repoId = component.get('v.repo').id;
    action.setCallback(this, function(data) {
      var options = {
        successCb : function() {
          component.set('v.repo', data.getReturnValue()[0]);
        },
        errorCb : function(errorMessage) {
          helper.addPageMessage("error", errorMessage);
        }
      };
      BW.LTCommon.auraCallbackHandler(data, options);
    });
    action.setParams({
      repoId: repoId
    });
    $A.enqueueAction(action);
  },
  refreshButtonDisabledState : function(component) {
    var sshKeyExists = $A.util.getBooleanValue(component.get('v.userHasExistingKeypair'));
    component.set("v.disableTestButton", !sshKeyExists);
  },

  validateGitConnectionHandler : function(component, event, helper) {
    var repoId = component.get('v.repo').id;
    var action = component.get('c.validateGitConnection');
    component.set("v.disableTestButton", true);
    action.setCallback(this, function(data) {
      var options = {
        successCb : function() {
          component.set("v.disableTestButton", false);
          helper.clearPageMessages();
          helper.refreshVCRecord(component);
        },
        errorCb : function(errorMessage) {
          component.set("v.disableTestButton", false);
          helper.addPageMessage("error", errorMessage);
        }
      };
      BW.LTCommon.fireGoogleAnalyticsTrackingEvent('Version Control', 'Test User Repository Connection', 'Version Control - SSH Connection');
      BW.LTCommon.auraCallbackHandler(data, options);
    });
    action.setParams({
      vcRepositoryId: repoId
    });

    $A.enqueueAction(action);
  }
});