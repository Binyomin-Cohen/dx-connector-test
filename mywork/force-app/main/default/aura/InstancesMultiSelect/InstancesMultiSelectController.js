({
  init: function(component, event, helper) {
    helper.setInstanceComponents(component);
  },

  handleChildSelect: function(component, event, helper) {
    helper.refreshSelectedInstancesText(component);
  },

  handleInstancesChange: function(component, event, helper) {
    helper.setInstanceComponents(component);
  },

  setInstances: function(component, event, helper) {
    var instances = event.getParam('arguments').instances
    if (instances.length > 0) {
      component.set('v.instances', instances);
      helper.setInstanceComponents(component);
    }
  },

  getSelectedInstanceNames: function(component, event, helper) {
    return component.getSelectedChildren().map(function(comp) {
      return comp.get("v.instance").name.trim();
    });
  },
})
