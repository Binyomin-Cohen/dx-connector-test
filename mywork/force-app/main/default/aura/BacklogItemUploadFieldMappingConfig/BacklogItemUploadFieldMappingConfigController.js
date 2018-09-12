({
  init: function(component, event, helper) {
    helper.updateUnmappedSalesforceFieldsComboboxOptions(component, event, helper);
    helper.updateUploadedColumnComboboxOptions(component, event, helper);

    var salesforceFieldName = component.get('v.config.salesforceFieldName'),
      isMapped = component.get('v.config.isMapped');

    if (isMapped === true) {
      helper.handleLookupFieldChange(component, salesforceFieldName);
    }
  },

  comboBoxChangeEventHandler : function(component, event, helper) {
    helper.handleComboBoxChangeEvent(component, event);
  },

  handleCreateNewRelatedChange : function(component, event, helper) {
    var createNewRecords = event.getSource().get("v.label") === "Create new values";
    component.set("v.config.lookupDetail.createNewRelatedRecords", createNewRecords);
  },

  handleRadioButtonsValueChange : function (component, event, helper) {
    var createNewRelatedRecords = component.get("v.radioButtonsSelectedValue") === 'Create new values';
    component.set("v.config.lookupDetail.createNewRelatedRecords", createNewRelatedRecords);
  },

  initModal : function(component, event, helper) {
    var modal = $(event.target).closest("td").find(".alm-modal");

    BW.AlmCommon.displayModal({
      content: modal,
      width : '800px',
      height : '600px',
      overflow: 'visible'
    });
  },

  updateUnmappedSalesforceFieldsComboboxOptions: function(component, event, helper) {
    helper.updateUnmappedSalesforceFieldsComboboxOptions(component, event, helper);
  },

  updateUploadedColumnComboboxOptions: function(component, event, helper) {
    helper.updateUploadedColumnComboboxOptions(component, event, helper);
  },


})
