({
  getInputElement: function(component) {
    return component.find("dropdown-input").getElement();
  },

  enableInput: function(component, event, helper) {
    var inputElement = helper.getInputElement(component);
    if (inputElement) {
      inputElement.removeAttribute("disabled");
    }
  },

  disableInput: function(component, event, helper) {
    var inputElement = helper.getInputElement(component);
    if (inputElement) {
      inputElement.disabled = true;
    }
  },
})
