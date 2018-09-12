({
  filterComponents : function(component) {
    var filterType = $('#related-components-filter-container .filter-values').val();
    component.set("v.selectedFilterChoice", filterType);
    
    var appEvent = $A.get("e.c:findDependentComponentsEvent");
    if (appEvent) {
      appEvent.setParams({ "relatedComponentsFilterChoice" : filterType });
      appEvent.fire();
    }
    
  }
})
