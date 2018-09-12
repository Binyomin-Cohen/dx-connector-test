({
  init : function(component, event, helper) {
    helper.init( component );
  },
  instancesInit : function(component, event, helper) {
    helper.instancesInit( component );
  },
  doSearch : function(component, event, helper) {
    helper.doSearch( component );
  },
  formKeyPress : function(component, event, helper) {
    helper.formKeyPress( component, event );
  },
  handleEnableParamChange : function(component, event, helper) {
    helper.enableSearchButton(component);
  },
  handleUsersFilters : function(component, event, helper) {
    helper.updateUserFilterLabel(component, helper);
  }
});
