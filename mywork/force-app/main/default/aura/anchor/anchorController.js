({
  populateVisualForceURLNamespace : function(component, event, helper) {
    var url = component.get('v.value');
    
    if (url && url.indexOf('/apex/') !== -1) {
      helper.doPopulateVisualForceURLNamespace(component);
    }
  }
})