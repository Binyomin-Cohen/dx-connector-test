({
  handleComboBoxChangeEvent : function(component, event) {
    var selectedValue = event.getParam('newValue');

    var isRequiredField = component.get('v.config.isRequired');
    if (isRequiredField){
      var availableColumns = component.get('v.uploadedColumns');
      var isMapped = (availableColumns.indexOf(selectedValue) > -1);
      component.set('v.config.columnName', selectedValue);
      component.set('v.config.isMapped', isMapped);
      if (isMapped){
        var columnIndex = component.get('v.uploadedColumns').indexOf(selectedValue);
        var dataRows = component.get('v.dataRows');
        if (columnIndex > -1 && dataRows){
          component.set('v.config.sampleUploadedData', dataRows[0][columnIndex]);
        }
      } else {
        component.set('v.config.sampleUploadedData', '');
      }
      this.handleLookupFieldChange(component, selectedValue);
    } else {
      var allSalesforceFields = component.get('v.allSalesforceFields');
      var unmappedSalesforceFields = component.get('v.unmappedSalesforceFields');
      var validSalesforceFieldSelectedIndex = allSalesforceFields.indexOf(selectedValue);
      var unmappedSalesforceFieldSelectedIndex = unmappedSalesforceFields.indexOf(selectedValue);

      var validSalesforceFieldSelected = validSalesforceFieldSelectedIndex > -1;
      component.set('v.config.isMapped', validSalesforceFieldSelected);

      if (!validSalesforceFieldSelected) {
        component.set("v.config.isLookup", false);
      }

      if (unmappedSalesforceFieldSelectedIndex > -1){
        component.set('v.config.salesforceFieldName', selectedValue);
        unmappedSalesforceFields.splice(unmappedSalesforceFieldSelectedIndex, 1);
        component.set('v.unmappedSalesforceFields', unmappedSalesforceFields );
        this.handleLookupFieldChange(component, selectedValue);
      }
    }
  },

  handleLookupFieldChange : function(component, selectedApiName) {
    var fieldMappingConfig = component.get('v.config'),
        lookupFieldApiNames = component.get('v.lookupFieldApiNames');

    if (fieldMappingConfig.isRequired) {
      selectedApiName = fieldMappingConfig.salesforceFieldName;
    } else {
      fieldMappingConfig.salesforceFieldName = selectedApiName;
    }

    var isLookup = (lookupFieldApiNames.indexOf(selectedApiName) !== -1);

    component.set("v.config.isLookup", isLookup);
    component.set("v.config.salesforceFieldName", fieldMappingConfig.salesforceFieldName);
    if (!isLookup) {
      return;
    }

    var resultsColumn = component.find('lookup-results');
    $A.util.addClass(resultsColumn, 'processing');

    var getMappingConfigurationsAction = component.get("c.getRelatedRecords");
    getMappingConfigurationsAction.setParams({
      fieldMappingConfigJSON : JSON.stringify(fieldMappingConfig),
      lookupValues : this.getColumnData(component)
    });

    getMappingConfigurationsAction.setCallback(this, function(data) {
      var options = {};
      options.successCb = $A.getCallback(function() {
         var updatedLookupDetail = data.getReturnValue();
         component.set("v.config.lookupDetail", updatedLookupDetail);
      });
      options.cb = $A.getCallback(function() {
        if (component.isValid()) {
            $A.util.removeClass(resultsColumn, 'processing');
        }
      });
      BW.LTCommon.auraCallbackHandler(data, options);
    });
    $A.enqueueAction(getMappingConfigurationsAction);
  },

  getColumnData : function(component) {
    var columnName = component.get('v.config.columnName'),
     columnIndex = component.get('v.uploadedColumns').indexOf(columnName),
     dataRows = component.get('v.dataRows');

    return dataRows.map(function(row) {
      return row[columnIndex];
    });
  },

  updateUnmappedSalesforceFieldsComboboxOptions: function(component, event, helper) {
    var fieldNames = component.get('v.unmappedSalesforceFields') || [];
    component.set('v.unmappedSalesforceFieldsComboboxOptions', fieldNames.map(function(name) {
      return {value: name, label: name};
    }));
  },

  updateUploadedColumnComboboxOptions: function(component, event, helper) {
    var colNames = component.get('v.uploadedColumns') || [];
    component.set('v.uploadedColumnComboboxOptions', colNames.map(function(name) {
      return {value: name, label: name};
    }));
  },

})
