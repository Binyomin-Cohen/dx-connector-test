({
  handleChildMultiSelect : function(component, selectedChild, helper) {
    var previouslySelectedChild = component.get("v.mostRecentlySelectedChild");
    if (!previouslySelectedChild || !selectedChild) { return; }

    var compsToMultiSelect = this.getComponentsBetween(previouslySelectedChild, selectedChild, component),
        newSelectedStatus = previouslySelectedChild.isSelected();
    if (compsToMultiSelect.length > 0 && typeof newSelectedStatus === 'boolean') {
      compsToMultiSelect.forEach(function(comp) {
        comp.setSelected(newSelectedStatus);
      });
    }
  },

  /** Retrieves a list of components between comp1 and comp2. The order of comp1 and comp2 does not matter.
   *  Returns an empty list if no rows are found.
   */
  getComponentsBetween : function(comp1, comp2, self) {
    var foundComp1 = false,
        foundComp2 = false,
        compsInRange = [],
        comp;

    var children = self.get('v.children');
    for (var i = 0; i < children.length; i++) {
      comp = children[i];
      // TODO: is the global Id ok to use?
      foundComp1 = (foundComp1 || comp.getId() === comp1.getId());
      foundComp2 = (foundComp2 || comp.getId() === comp2.getId());

      if (foundComp1 || foundComp2) {
        compsInRange.push(comp);
      }
      if (foundComp1 && foundComp2){
        break;
      }
    }
    // only return comps if a valid range has been found
    return (foundComp1 && foundComp2) ? compsInRange : [];
  },

  findChildComponentIndex: function(component, childComponent) {
    var children = component.get('v.children'),
        index = -1;

    for (var i = 0; i < children.length; i++) {
      var child = children[i];
      if (child.getId() === childComponent.getId()) {
        index = i;
        break;
      }
    }
    return index;
  },

  setFocusedChildIndex: function(focusedChildComponent, thisComponent) {
    var childIndex = this.findChildComponentIndex(thisComponent, focusedChildComponent);
    if (childIndex > -1) {
      thisComponent.set('v.focusedChildIndex', childIndex);
    }
  },


})
