({
  addEventHandlers : function(component){
    $( "#alm-container" ).on( "change", ".search-components-table-content .selected-comp-cb input.fancy-checkbox", function(e) {
      if (component.isValid()){
        var componentRecord = component.get('v.componentRecord');
        var currentComponentKey = componentRecord.key;
        var currentComponentCheckedValue = componentRecord.checked;
        if (currentComponentKey == this.dataset.key && currentComponentCheckedValue !== this.checked){
          if (!componentRecord.existsOnCurrentBacklog) {
            componentRecord.checked = this.checked;
            component.set("v.componentRecord", componentRecord);
            component.getEvent("rowSelectEvent").fire();
          }
        }
      }
    });
  },
});
