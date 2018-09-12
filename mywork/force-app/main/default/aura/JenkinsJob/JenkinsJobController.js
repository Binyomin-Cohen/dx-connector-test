({

  doInit : function(component, event, helper) {
    helper.init(component);
  },

  startJenkinsJob : function(component, event, helper) {
    component.set("v.jobInProgress" , true);
    helper.startJenkinsJob(component);
  },

  handleComboBoxChanges : function(component, event, helper) {
    helper.comboboxChange(component, event);
  }

});