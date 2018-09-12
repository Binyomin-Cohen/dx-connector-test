({

  doInit : function(component, event, helper) {
    helper.init(component);
  },

  handleCommitMessage : function(component, event, helper) {
    helper.handleCommitMessage(component, event);
  },

  handleCommitButtonToggle : function(component, event, helper) {
    helper.handleCommitButtonToggle(component);
  },

  handleCommitButtonClick : function(component, event, helper) {
    helper.commitChanges(component, event);
    BW.LTCommon.fireGoogleAnalyticsTrackingEvent('Version Control','Commit Backlog Item Components');
  },

  handleSelectedBacklogComponentIdsChange : function(component, event, helper) {
    helper.handleSelectedBacklogComponentIdsChange(component, event, helper);
  },

  handleCommitMessagePlaceholder : function(component, event, helper) {
    helper.toggleCommitMessagePlaceholder(component);
  },

  getState : function(component, event, helper) {
    helper.getState(component, event.getParam('arguments').state);
  },

  setState : function(component, event, helper) {
    helper.setState(component, event.getParam('arguments').state);
  }
});
