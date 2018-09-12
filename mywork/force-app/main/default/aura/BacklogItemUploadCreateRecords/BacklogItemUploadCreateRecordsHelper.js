({
  updateLookupRecordCount : function(component) {
    var allConfigData = this.getAllMappingConfigRows(component);
    var lookupRecordCount = 0;

    allConfigData.forEach(function(mapping) {
      if (mapping.isMapped && mapping.isLookup
       && mapping.lookupDetail.createNewRelatedRecords && !mapping.lookupDetail.hasLookupError) {
        lookupRecordCount += mapping.lookupDetail.newRelatedRecords.length;
      }
    });

    component.set("v.lookupRecordCount", lookupRecordCount);
  },

  createRecords: function(component) {
    var createRecordsAction = component.get("c.createRecords");

    var dataRows = component.get("v.parsedUploadFile.rows");

    var mappingConfigData = component.get("v.mappingConfigData");
    mappingConfigData.unmappedFields = BW.LTCommon.getSelectOptionValues(mappingConfigData.unmappedFields);
    var fieldMappingCongigJSON = JSON.stringify(mappingConfigData);
    createRecordsAction.setParams({
      mappingConfigDataJSON : fieldMappingCongigJSON,
      columnHeaderIndexRecordsJSON : JSON.stringify(this.mapColumnNameToIndex(component)),
      backlogItemRecordsJSON : JSON.stringify(dataRows)
    });

    createRecordsAction.setCallback(this, function(data) {
      var options = {};
      options.cb = $A.getCallback(function() {
        if (component.isValid()) {
          $A.util.addClass(component.find('progress-summary'), 'load-complete');
        }
      });
      options.successCb = function() {
        component.set("v.uploadResult", data.getReturnValue());
      };
      BW.LTCommon.auraCallbackHandler(data, options);
    });
    $A.enqueueAction(createRecordsAction);
  },

  mapColumnNameToIndex : function(component) {
    var columnNames = component.get("v.mappingConfigData.uploadedColumnNames");
    var allConfigData = this.getAllMappingConfigRows(component);

    var columnNameToIndex = {};

    allConfigData.forEach(function(mapping) {
      columnNameToIndex[mapping.columnName] = columnNames.indexOf(mapping.columnName);
    });

    return columnNameToIndex;
  },

  getAllMappingConfigRows : function(component) {
    var reqConfigData = component.get("v.mappingConfigData.requiredMappingConfigurations") || [];
    var configData = component.get("v.mappingConfigData.mappingConfigurations") || [];
    return configData.concat(reqConfigData);
  }
})
