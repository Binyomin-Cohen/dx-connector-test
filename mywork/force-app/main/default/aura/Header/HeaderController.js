({
  init : function(component, event, helper) {
    $('#banner-sub-menu .action.search').click(helper.scrollToSearchForm);
    
    var backToLink =
        $A.util.isUndefinedOrNull(component.get('v.customBackToLink')) ?
        component.get('v.homeUrl') :
        component.get('v.customBackToLink');
    component.set('v.backToLink', backToLink);
    component.find('backToAnchor').updateValue();
  },

  handleSaveEvent : function(cmp, event) {
    var isSaveComplete = event.getParam("isSaveComplete");
    cmp.set("v.showSavingState", isSaveComplete === false);
  }
})