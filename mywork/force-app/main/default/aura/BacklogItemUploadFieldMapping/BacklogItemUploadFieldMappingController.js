({

  initMappingConfigurations : function(component, event, helper) {
    var uploadedColumnNames = component.get('v.parsedUploadFile.headers');
    helper.populateMappingConfigurations(component, uploadedColumnNames);
  },

  handleComboBoxChanges : function(component, event, helper){
    helper.comboBoxChangeHandler(component, event);
  },
  
  handleStepChange : function(component, event, helper){
    helper.stepChangeHandler(component, event);
  }

})