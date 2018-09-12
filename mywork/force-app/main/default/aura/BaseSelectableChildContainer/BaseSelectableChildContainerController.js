({
  handleChildSelect: function(component, event, helper) {
    document.getSelection().removeAllRanges(); // un-highlights selected text from the multi-select

    var selectedComp = event.getParam('component')
    if (!selectedComp) {return;}

    if (event.getParam('isMultiSelect')) {
      helper.handleChildMultiSelect(component, selectedComp, helper);
    } else {
      component.set('v.mostRecentlySelectedChild', selectedComp);
    }
  },

  getSelectedChildren: function(component) {
    return component.get('v.children').filter(function(childComp) {
      return childComp.isSelected();
    });
  },

  focusNext: function(component, event, helper) {
    var children = component.get('v.children');

    if (children.length > 0) {
      var focusedCompIndex = component.get('v.focusedChildIndex') || 0,
          nextCompIndex = (focusedCompIndex + 1) % children.length;
      component.set('v.focusedChildIndex', nextCompIndex);
      children[nextCompIndex].focus();
    }
  },

  focusPrevious: function(component, event, helper) {
    var children = component.get('v.children');

    if (children.length > 0) {
      var focusedCompIndex = component.get('v.focusedChildIndex') || 0,
          prevCompIndex = (focusedCompIndex - 1 + children.length) % children.length;
      component.set('v.focusedChildIndex', prevCompIndex);
      children[prevCompIndex].focus();
    }
  },

  handleKeydown: function(component, event, helper) {
    var CHAR_KEYCODES = {UP_ARROW: 38, DOWN_ARROW: 40}
    switch (event.keyCode) {
      case CHAR_KEYCODES.UP_ARROW:
        component.focusPrevious(component, event, helper);
        return;
      case CHAR_KEYCODES.DOWN_ARROW:
        component.focusNext(component, event, helper);
        return;
    }
  },

  handleChildVirtualDOMEvent: function(component, event, helper) {
    var type = event.getParam("type");
    if (type === 'focus') {
      const focusedChildComponent = event.getParam("component");
      // track which child is currently focused in order to enable focusing previous/next child component
      helper.setFocusedChildIndex(focusedChildComponent, component);
    }
  },

})
