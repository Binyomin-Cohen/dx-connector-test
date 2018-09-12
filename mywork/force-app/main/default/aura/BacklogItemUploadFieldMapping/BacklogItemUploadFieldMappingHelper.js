({

  hasAllRequiredFieldsMapped : function(requiredMappings){
    var requiredMappingIndex;
    for (requiredMappingIndex in requiredMappings){
      var requiredMapping = requiredMappings[requiredMappingIndex];
      if (!requiredMapping.isMapped){
        return false;
        break;
      }
    }
    return true;
  },

  showAdditionalFields : function(component){
    var isNextButtonEnabled = component.get('v.enableNextButton');
    var hasUnmappedRequiredFields = component.get('v.hasUnmappedRequiredFields');
    var requiredMappingConfigurations = component.get('v.mappingConfigData.requiredMappingConfigurations');
    var hasAllRequiredFieldsMapped = this.hasAllRequiredFieldsMapped(requiredMappingConfigurations);
    var self = this;

    if ((hasUnmappedRequiredFields && requiredMappingConfigurations.length == 0) ||
        (hasUnmappedRequiredFields && hasAllRequiredFieldsMapped ))
    {
      component.set('v.showLoadingFieldsSpinner', true);
      window.setTimeout($A.getCallback(function() {
        if (component.isValid()) {
          component.set('v.showLoadingFieldsSpinner', false);
          component.set('v.hasUnmappedRequiredFields', false);
          self.stepChangeHandler(component)
        }
      }), 3000);
    } else if (!hasAllRequiredFieldsMapped) {
      // Unmapped a required field
      component.set("v.enableNextButton", false);
    } else if (!isNextButtonEnabled && hasAllRequiredFieldsMapped){
      // Next button disabled and required fields re-mapped
      component.set("v.enableNextButton", true);
    }
  },

  comboBoxChangeHandler : function(component, event){
    this.showAdditionalFields(component);
    var currentMappedSalesforceFields = [];
    var mappingConfigurations = component.get('v.mappingConfigData.mappingConfigurations');
    for (var i = 0; i < mappingConfigurations.length; i++){
      if (mappingConfigurations[i].isMapped && mappingConfigurations[i].salesforceFieldName){
        currentMappedSalesforceFields.push(mappingConfigurations[i].salesforceFieldName)
      }
    }
    var updatedUnmappedFields = [];
    var allBacklogItemFields = component.get('v.mappingConfigData.allBacklogItemFields');
    for (var j = 0; j < allBacklogItemFields.length; j++){
      if (currentMappedSalesforceFields.indexOf(allBacklogItemFields[j]) == -1){
        updatedUnmappedFields.push(allBacklogItemFields[j]);
      }
    }
    component.set('v.mappingConfigData.unmappedFields', updatedUnmappedFields );
  },

  populateMappingConfigurations : function(component, columnNames) {

    // TODO: Make sure the automapped salesforce fields are removed from the unmapped fields options
    component.set('v.hasUnmappedRequiredFields', true); // default and reset
    var getMappingConfigurations = component.get("c.buildMappingConfigurations");
    getMappingConfigurations.setParams({
      columnNames : columnNames
    });
    var self = this;
    getMappingConfigurations.setCallback(this, function(data) {
      var options = {};
      options.successCb = function() {
        var mappingConfigData = data.getReturnValue();
        var parsedUploadFile = component.get('v.parsedUploadFile');
        var mappingConfigurations = mappingConfigData.mappingConfigurations;
        for (var i = 0; i < mappingConfigurations.length; i++){
          if (mappingConfigurations[i].columnName){
            var columnIndex = mappingConfigData.uploadedColumnNames.indexOf(mappingConfigurations[i].columnName);
            if (columnIndex > -1){
              if (parsedUploadFile.rows.length > 0){
                mappingConfigurations[i].sampleUploadedData = parsedUploadFile.rows[0][columnIndex];
              }
            }
          }
        }
        var mappingConfigDataRequired = mappingConfigData.requiredMappingConfigurations;
        var mappingConfigDataOthers = mappingConfigData.mappingConfigurations;
        mappingConfigData.mappingConfigurations = [];
        mappingConfigData.requiredMappingConfigurations = [];
        component.set("v.mappingConfigData", mappingConfigData);
        component.set("v.mappingConfigData.requiredMappingConfigurations", mappingConfigDataRequired);
        component.set("v.mappingConfigData.mappingConfigurations", mappingConfigDataOthers);
        self.showAdditionalFields(component);
      };
      BW.LTCommon.auraCallbackHandler(data, options);
    });
    $A.enqueueAction(getMappingConfigurations);
  },

  stepChangeHandler : function(component, event){
    var enableNextButton = !component.get('v.hasUnmappedRequiredFields');
    if (enableNextButton){
      component.set("v.enableNextButton", false); // reset to trigger change handler
      component.set("v.enableNextButton", enableNextButton);
    }
  }

})