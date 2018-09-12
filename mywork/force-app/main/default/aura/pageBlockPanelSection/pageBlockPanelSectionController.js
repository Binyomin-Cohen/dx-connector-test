({
  fireNextPageRequestEvent : function(component, event, helper) {
    if (component.get('v.enablePagingNext') === true){
      var pagingEvent = component.getEvent("pagingRequestEvent");
      // TODO: make next a constant
      pagingEvent.setParam("pagingDirection", "next");
      pagingEvent.fire();
    }
  },

  firePrevPageRequestEvent : function(component, event, helper) {
    if (component.get('v.enablePagingPrevious') === true){
      var pagingEvent = component.getEvent("pagingRequestEvent");
      // TODO: make previous a constant
      pagingEvent.setParam("pagingDirection", "previous");
      pagingEvent.fire();
    }
  },

  handleActionButtonClick : function(component, event, helper) {
    if (component.get("v.enableActionButton")) {
      component.getEvent("componentSaveEvent").fire();
    }
  }
});
