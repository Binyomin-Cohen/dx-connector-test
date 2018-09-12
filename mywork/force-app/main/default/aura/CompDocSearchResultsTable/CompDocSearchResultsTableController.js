({
  handleSelectAllChange : function(component, event, helper) {
    var checkbox = $('#' + component.get("v.tableSelectAllCheckboxId"))[0];
    checkbox.checked = component.get("v.selectAll");
  },

  doInit : function(component, event, helper) {
    component.set('v.columns', [
      {label : 'Instance', styleClass: 'searchResultsHeader'},
      {label : 'Name', styleClass: 'searchResultsHeader'},
      {label : 'Type', styleClass: 'searchResultsHeader'},
      {label : 'Parent Component', styleClass: 'searchResultsHeader'},
      {label : 'Last Modified Date', styleClass: 'searchResultsHeader'},
      {label : 'Last Modified By', styleClass: 'searchResultsHeader'},
    ]);
  }
});
