({
  populateLookupRecordCount : function(component, event, helper) {
    var CREATE_RECORD_STEP = 3;
    if (component.get("v.step") === CREATE_RECORD_STEP) {
      helper.updateLookupRecordCount(component);
      helper.createRecords(component);
    }
  }
})