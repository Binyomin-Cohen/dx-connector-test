({
  handlePageMessageAddEvent : function(component, event, helper) {
    var messages = component.get('v.messages');
    messages.push({type: event.getParam('type'), message: event.getParam('message'), 
                   urlValue: event.getParam('urlValue'), urlTitle: event.getParam('urlTitle'), 
                   urlLabel: event.getParam('urlLabel'), urlAdditionalText: event.getParam('urlAdditionalText')});
    component.set('v.messages', messages);
  },

  handlePageMessagesClearEvent: function(component, event, helper) {
    component.set('v.messages', []);
  },

  handlePageMessageRemoveEvent : function (component, event, helper) {
    var messages = component.get('v.messages');
    var messageId = event.getParam('messageId');

    for(var i = 0; i < messages.length; i++) {
      if (messages[i].id === messageId) {
        messages.splice(i, 1);
      }
    }

    component.set('v.messages', messages);
  }

});