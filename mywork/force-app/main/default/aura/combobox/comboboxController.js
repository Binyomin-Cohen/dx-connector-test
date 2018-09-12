({
  doInit : function(component, event, helper) {
    helper.initCombobox(component);
  },

  handleOptionsChange : function(component, event, helper) {
    var options = component.get('v.options') || [];
    if (typeof BW !== 'undefined' && BW.LTCommon && BW.ComboBox) {
      if (BW.LTCommon.isListOfStrings(options)) {
        component.set('v.options', BW.LTCommon.convertStringsToSelectOptions(options));
      }

      if (!component.get('v.initCompleted')) {
        helper.setComboboxAccess(component);
        component.set("v.initCompleted", true);
      }
    }

    helper.setVisibleOptions(component);
  },

  handleDisabledChange : function(component, event, helper) {
    helper.setComboboxAccess(component);
  },

  handleComboboxValueChange : function(component, event, helper) {
    helper.handleComboboxValueChange(component, event);
  },

  handleRemoveSelectedOption : function(component, event, helper) {
    var value = event.target.parentNode.parentNode.getAttribute('data-value');
    helper.removeSelectedValue(component, value);
  },

  setValue : function(component, event, helper) {
    var selectedLabel = helper.getSelectedLabel(component, event.getParam('arguments').value);

    component.set('v.selectedLabel', selectedLabel);

    helper.handleComboboxValueChange(component, { target : { value : selectedLabel } });
  },

  handleClearFilterSelections : function(component, event, helper) {
    if (component.get("v.isMultiSelect")) {
      component.set("v.selectedOptions", []);
      helper.setVisibleOptions(component);
    }
  }

});