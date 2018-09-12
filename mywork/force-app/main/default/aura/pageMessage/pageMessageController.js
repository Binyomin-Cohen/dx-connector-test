({
  init : function(component, event, helper) {
    component.set('v.message.id', component.getGlobalId());
  },

  handleRemoveMessageRequest : function(component, event) {
    var removeEvent = component.getEvent('pageMessageDelete');
    removeEvent.setParam('messageId', component.get('v.message.id'));
    removeEvent.fire();
  }
});
