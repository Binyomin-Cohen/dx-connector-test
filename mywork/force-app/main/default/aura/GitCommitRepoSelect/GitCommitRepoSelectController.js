({
  doInit : function(component, event, helper) {
   helper.populateAvailableRepos(component);
  },

  handleComboBoxChanges : function(component, event, helper) {
    var comboboxId = event.getParam('comboboxId');
    if (comboboxId === component.get('v.repoSelectComboboxId')) {
      var repoId = event.getParam('newValue');
      helper.selectRepo(component, repoId);
    } else if (comboboxId === component.get('v.branchSelectComboboxId')) {
      var branchName = event.getParam('newValue');
      helper.selectBranch(component, branchName);
    }
  },

  getState : function(component, event, helper) {
    return helper.getState(component, event.getParam('arguments').state);
  },

  setState : function(component, event, helper) {
    helper.setState(component, event.getParam('arguments').state);
  },

  selectRepo: function(component, event, helper) {
    var params = event.getParam('arguments');
    helper.selectRepo(component, params.repoId);
  }
})
