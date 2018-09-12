({
  isSelected : function(component, event, helper) {
    return component.find('selected-checkbox').isChecked();
  },

  setSelected: function(component, event, helper) {
    const newSelectedStatus = event.getParam('arguments').isSelected;
    component.find('selected-checkbox').setChecked(newSelectedStatus);

    var isMultiSelect = false;
    component.notifyParentOfSelect(isMultiSelect);
  },

  handleCheckboxChangeEvent: function(component, event, helper) {
    const isMultiSelect = event.getParam('isMultiSelect');
    component.notifyParentOfSelect(isMultiSelect);
  },
})
