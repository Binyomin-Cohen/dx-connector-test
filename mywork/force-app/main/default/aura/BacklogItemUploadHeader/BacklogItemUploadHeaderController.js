({
  next : function(component, event, helper) {
    helper.next( component );
  },
  previous : function(component, event, helper) {
    helper.previous( component );
  },
  adjustButtons : function(component, event, helper) {
    helper.adjustButtons( component );
  },
  toggleNextButton : function(component, event, helper) {
    helper.toggleNextButton( component );
  }
})