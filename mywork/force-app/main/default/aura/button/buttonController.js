({
  handleOnClick : function (component, event, helper) {
    var onclickFunction = component.get("v.onclick");
    if (onclickFunction && ((typeof onclickFunction) === "function") ) {
        onclickFunction();
    }
    helper.fireButtonEvent(component);
  },

  focusButton : function (component) {
    component.find("button").focus();
  }
});