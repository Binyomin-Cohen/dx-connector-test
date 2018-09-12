({
  onPostRender: function(component, event, helper) {
    if (component.get('v.userTextInputDisabled')) {
      helper.disableInput(component, event, helper);
    } else {
      helper.enableInput(component, event, helper);
    }

    window.addEventListener("click", function(event) {
      var dropDownElem = component.getElement();
      if (dropDownElem && !dropDownElem.contains(event.target)) {
        component.close();
      }
    });
  },

  handleKeydown: function(component, event, helper) {
    var CHAR_KEYCODES = {ESC: 27}
    switch (event.keyCode) {
      case CHAR_KEYCODES.ESC:
        component.close();
        return;
    }
  },

  toggleOpenClose: function(component, event, helper) {
    component.set('v.openDropdown', !component.get('v.openDropdown'));
  },

  open: function(component, event, helper) {
    component.set('v.openDropdown', true);
  },

  close: function(component, event, helper) {
    component.set('v.openDropdown', false);
  },

  handleInputTextClick: function(component, event, helper) {
    if (component.get('v.userTextInputDisabled')) {
      component.toggleOpenClose(component, event, helper);
    }
  },

  enableUserTextInput: function(component, event, helper) {
    helper.enableInput(component, event, helper);
  },

  disableUserTextInput: function(component, event, helper) {
    helper.disableInput(component, event, helper);
  },

})
