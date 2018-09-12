({
  init : function(component, event, helper) { 
    helper.populateAvailableOptions(component);
  },

  handleComboboxChanges : function(component, event, helper) {
    var newCriteria = event.getParam('newValue');
    if (newCriteria) {
      helper.addCriteria(component, newCriteria);
    }
  },

  handleComboboxDelete : function(component, event, helper) {
    var deletedCriteria = event.getParam('value');
    
    if (deletedCriteria) {
      helper.deleteCriteria(component, deletedCriteria);
    }
  }

})