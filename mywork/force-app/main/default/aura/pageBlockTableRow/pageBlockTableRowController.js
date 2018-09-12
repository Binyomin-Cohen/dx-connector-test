({
  handleRowSelect : function(component, event, helper) {
    event.preventDefault();
    if (component.isValid()) {
      var componentRecord = component.get('v.componentRecord'),
          isMultiSelect = event.shiftKey;

      componentRecord.checked = !componentRecord.checked;
      component.set('v.componentRecord', componentRecord);

      var rse = component.getEvent('rowSelectEvent');
      rse.setParams({"rowId": componentRecord.key, "isMultiSelect": isMultiSelect});
      rse.fire();
    }
  }
});
