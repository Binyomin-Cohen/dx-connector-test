({
  init: function(component, event, helper) {
    helper.loadProfiles(component);
    helper.addEventListeners();
  },
  refreshProfiles: function(component, event, helper) {
    var isSaveComplete = event.getParam("isSaveComplete");
    if (isSaveComplete === true) {
      helper.loadProfiles(component);
    }
  },
  deleteAllProfiles: function(component, event, helper) {
    helper.handleDeleteAllClick(component);
  },
  saveProfile: function(component, event, helper) {
    helper.saveProfile(component, event);
  }
})