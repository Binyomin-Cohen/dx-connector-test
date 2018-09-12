({
  init : function(component, event, helper) {
    helper.refreshButtonDisabledState(component);
  },

  refreshButtonDisabledState : function(component, event, helper) {
    helper.refreshButtonDisabledState(component);
  },

  handleButtonClick : function(component, event, helper) {
    var actionType = event.getParam("actionType");

    if (actionType === "validateGitConnectionHandler") {
      helper.validateGitConnectionHandler(component, event, helper);
    }
  }
});