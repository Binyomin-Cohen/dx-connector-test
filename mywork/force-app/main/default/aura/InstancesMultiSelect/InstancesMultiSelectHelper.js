({
  refreshSelectedInstancesText: function(component) {
    var selectedCompNames = component.getSelectedChildren(component).map(function(comp) {
      return comp.get("v.instance").name;
    });

    var selectedInstancesText;
    if (selectedCompNames.length > 3) {
      selectedInstancesText = selectedCompNames.length + " Instances Selected";
    } else if (selectedCompNames.length > 0) {
      selectedInstancesText = selectedCompNames.join(", ");
    } else {
      selectedInstancesText = "Select Instance(s)";
    }
    component.set('v.selectedInstancesText', selectedInstancesText);
  },

  setInstanceComponents: function(component) {
    var rows = component.get('v.instances').map(function (instance) {
      return ['c:InstancesMultiSelectRow', {instance: instance}];
    });

    $A.createComponents(rows, function (newRows, status, errorMessage) {
      component.set('v.children', newRows);
    })
  },

})
