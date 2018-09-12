({
  initCombobox : function(component) {
    var self = this;

    var options = component.get('v.options') || [];
    if (BW.LTCommon.isListOfStrings(options)){
      component.set('v.options', BW.LTCommon.convertStringsToSelectOptions(options));
    }
    var inputSelector = '#' + component.get('v.inputId');
    var appendToSelector = '#' + component.get('v.inputId') + '_almComboboxWrapper';
    BW.ComboBox.init({
     // parentContainer : appendToSelector,
      inputSelector : inputSelector,
      appendTo : appendToSelector,
      isMultiSelect : component.get('v.isMultiSelect'),
      selectAction : $A.getCallback(function(newValue) {
        self.handleInputChange(component, newValue);
      })
    });
    BW.ComboBox.initComboboxBehavior($(inputSelector), $(appendToSelector));

    var currentSelectedValue = component.get('v.selectedValue');
    var currentSelectedLabel = this.getSelectedLabel(component, currentSelectedValue);
    if (currentSelectedValue && currentSelectedValue.length > 0){
      if (currentSelectedLabel.length > 0){
        component.set('v.selectedLabel', currentSelectedLabel);
      } else {
        component.set('v.selectedLabel', currentSelectedValue);
      }
    }
    if (this.getDisabledFlag(component)){
      this.disableCombobox(component);
    }

    this.setVisibleOptions(component);
  },

  setComboboxAccess : function(component){
    if (this.getDisabledFlag(component)){
      this.disableCombobox(component);
    } else {
      this.enableCombobox(component);
    }
  },

  getDisabledFlag : function(component){
    var options = component.get('v.options') || [];
    return options.length === 0 || component.get('v.disabled');
  },

  handleInputChange : function(component, newValue) {
    component.set('v.selectedValue', newValue);
    component.set('v.selectedLabel', this.getSelectedLabel(component, newValue));

    if (component.get('v.isMultiSelect') && newValue && component.get('v.selectedLabel')) {
      var selectedOptions = component.get('v.selectedOptions');
      var newOption = {
        'value': component.get('v.selectedValue'),
        'label': component.get('v.selectedLabel')
      };
      selectedOptions.push(newOption);
      component.set('v.selectedOptions', selectedOptions);
      component.set('v.selectedValue', '');
      component.set('v.selectedLabel', '');
    }

    this.fireComboBoxChangedEvent(component, newValue);
    this.setVisibleOptions(component);
  },

  getSelectedLabel : function(component, newValue) {
    var label = "";
    var options = component.get('v.options') || [];
    for (var index in options){
      if (options[index].value === newValue){
        return options[index].label || "";
      }
    }
    return label;
  },

  getSelectedValueFromLabel : function(component, label) {
    var options = component.get('v.options') || [];
    for (var index in options){
      if (options[index].label === label){
        return options[index].value || "";
      }
    }
    return null;
  },

  disableCombobox : function(component){
    var $currentInputBox = $(component.find('input-box').getElement());
    $currentInputBox.prop('disabled', true).addClass('inactive');
    $currentInputBox.siblings('a.expander').addClass('inactive');
    BW.ComboBox.disableExpander($currentInputBox.siblings('a.expander'));
  },

  enableCombobox : function(component){
    var $currentInputBox = $(component.find('input-box').getElement());
    $currentInputBox.prop('disabled', false).removeClass('inactive');
    $currentInputBox.siblings('a.expander').removeClass('inactive');
    BW.ComboBox.enableExpander($currentInputBox.siblings('a.expander'), $currentInputBox);
  },

  fireComboBoxChangedEvent : function(component, newValue){
    var comboboxChangedEvt = component.getEvent("comboboxChangeEvent");
    comboboxChangedEvt.setParam("comboboxId", component.get('v.inputId'));
    comboboxChangedEvt.setParam("newValue", newValue);
    comboboxChangedEvt.fire();
  },

  removeSelectedValue : function(component, valueToRemove) {
    var deleteEvent = component.getEvent("comboboxDeleteEvent");
    deleteEvent.setParam("comboboxId", component.get('v.inputId'));
    deleteEvent.setParam("value", valueToRemove);
    deleteEvent.fire();

    var selectedOptions = component.get('v.selectedOptions');

    for (var i = 0; i < selectedOptions.length; i++) {
      if (selectedOptions[i].value === valueToRemove) {
        selectedOptions.splice(i, 1);
        break;
      }
    }

    component.set('v.selectedOptions', selectedOptions);
    this.setVisibleOptions(component);
  },

  setVisibleOptions : function(component) {
    var visibleOptions = [];
    var selectedOptionsValues = {};

    var selectedOptions = component.get('v.selectedOptions');

    //exclude the selected option from the list of available options
    if (!component.get('v.isMultiSelect')) {
      selectedOptionsValues[component.get('v.selectedValue')] = component.get('v.selectedLabel');
    }

    for (var index in selectedOptions) {
      selectedOptionsValues[selectedOptions[index].value] = selectedOptions[index].label;
    }

    var masterOptions = component.get('v.options');
    for (var index in masterOptions ) {
      if (!(masterOptions[index].value in selectedOptionsValues)) {
        visibleOptions.push(masterOptions[index]);
      }
    }

    component.set('v.visibleOptions', visibleOptions);
  },

  handleComboboxValueChange : function(component, event){
    var fireComboboxChangeHandler = true;
    var labelValue = event.target.value;
    var value = this.getSelectedValueFromLabel(component, labelValue);
    if (component.get('v.requireValidPicklistValue') === true && labelValue) {
      var currentOptions = component.get('v.visibleOptions') || [];
      var currentOptionValues = currentOptions.map(function(option) {
        return option ? option.value : null;
      });
      if (currentOptionValues.indexOf(value) === -1){
        fireComboboxChangeHandler = false;
      }
    }
    if (fireComboboxChangeHandler === true){
      this.handleInputChange(component, value);
    }
  }

})