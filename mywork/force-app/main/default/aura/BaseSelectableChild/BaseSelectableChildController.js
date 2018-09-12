({
  handleRowSelect: function(component, event, helper) {
    event.preventDefault();
    if (component.isValid()) {
      component.set('v.isSelected', !component.get('v.isSelected'));

      var isMultiSelect = event.shiftKey;
      var evt = component.getEvent('rowSelectEvent');
      evt.setParams({"component": component, isMultiSelect: isMultiSelect});
      evt.fire();
    }
  },

  notifyParentOfSelect: function(component, event, helper) {
    const isMultiSelect = event.getParam('arguments').isMultiSelect;

    var evt = component.getEvent('rowSelectEvent');
    evt.setParams({component: component, isMultiSelect: isMultiSelect});
    evt.fire();
  },

  toggleSelected: function(component, event, helper) {
    component.setSelected(!component.isSelected());
  },

  getId: function(component, event, helper) {
    return component.getGlobalId();
  },

  handleKeydown: function(component, event, helper) {
    var CHAR_KEYCODES = {SPACE: 32, ENTER: 13};
    if (event.keyCode === CHAR_KEYCODES.ENTER || event.keyCode === CHAR_KEYCODES.SPACE) {
      component.toggleSelected();
    }
  },

  focus: function(component, event, helper) {
    component.find("body").getElement().focus();
    var evt = component.getEvent('VirtualDOMEvent');
    evt.setParams({"component": component, type: "focus"});
    evt.fire();
  },

})
