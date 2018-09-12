({
  handleSelectBlock : function(component, event, helper) {
    if (!component.get('v.disabled') && !component.get('v.selected')) {
      helper.navigateToRepoEdit(component);
    }
  }
});