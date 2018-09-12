({
  handleCheckboxClick: function(component, event, helper) {
    event.preventDefault();
    component.set('v.checked', !component.get('v.checked'));
    var isMultiSelect = event.shiftKey;

    var evt = component.getEvent('CheckboxChangeEvent');
    evt.setParams({
      component: component,
      isMultiSelect: isMultiSelect,
      newCheckboxValue: component.get('v.checked')
    });
    evt.fire();
  },

  isChecked: function(component, event, helper) {
    return component.get('v.checked');
  },

  setChecked: function(component, event, helper) {
    var selected = event.getParam('arguments').isChecked;
    component.set('v.checked', selected === true);
  },
})
