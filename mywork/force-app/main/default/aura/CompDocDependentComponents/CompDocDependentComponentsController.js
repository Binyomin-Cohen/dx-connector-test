({
  refreshComponents : function(component, event, helper) {
    const retries = 0;
    helper.ensureLibrariesAreDefined(retries, function() {
      helper.refreshComponents(component, event);
    });
  },

  doInit : function(component, event, helper) {
    const retries = 0;
    helper.ensureLibrariesAreDefined(retries, function() {
      helper.refreshComponents(component, event);
    });
  },

  handlePagingRequest : function(component, event, helper) {
    helper.handlePageNavigation(component, event, helper);
  },

  handleNewPageRequest : function(component, event, helper) {
    helper.getCurrentPageDependentComponents(component);
  },

  handleSortKeyChange : function(component, event, helper) {
    helper.updateComponentSortOrder(component);
  },

  handleAddComponentsEvent : function(component, event, helper) {
    helper.addComponents(component, event);
  },

  handleRowSelect : function(component, event, helper) {
    helper.rowSelect(component, event);
  }

});