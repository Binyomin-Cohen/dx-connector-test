({
  init : function(component, event, helper) {
    var sshKeyExists = $A.util.getBooleanValue(component.get('v.userHasExistingKeypair'));
    if (!sshKeyExists) {
      var repoSection = component.find('repo-section');
      $A.util.toggleClass(repoSection, 'section-disabled');
    }
    var action = component.get('c.loadVCReposWithValidationsForUser');
      action.setCallback(this, function(data) {
        var options = {
            successCb : function() {
              component.set('v.VCRepos', data.getReturnValue());
            },
            errorCb : function(errorMessage) {
              helper.addPageMessage("error", errorMessage);
            }
        };
        BW.LTCommon.auraCallbackHandler(data, options);
      });
      $A.enqueueAction(action);
  },

  handleButtonClick : function(component, event, helper) {
    var actionType = event.getParam("actionType");
    if (actionType === "showPublicKey") {
      helper.showPublicKey(component, event, helper);
    } else if (actionType === "copyToClipboard") {
      var textToCopy = component.get('v.publicKey');
      helper.copyToClipboard(component, textToCopy);
    } else if (actionType === "generateKeys") {
      helper.generateKeys(component, event, helper);
    }
  }

});