({
  handleSelectAllClick : function(component, event, helper) {
    var evt = component.getEvent("rowSelectEvent");
    evt.setParam("selectAll", event.target.checked);
    evt.fire();
  },

  handleSelectAllChange : function(component, event, helper) {
    var selectAll = event.getParam('arguments').selectAll;
    component.set('v.selectAllChecked', selectAll);
    $('#' + component.get('v.tableSelectAllCheckboxId')).prop('checked', selectAll);
  },

  handleSortClick : function(component, event, helper){
    const sortHeader = $(event.target).closest('th.sorting')[0];
    if (!sortHeader) return;

    const requestedSortKey = sortHeader.dataset.sort,
        requestedSortKeyType = sortHeader.dataset.sortDataType;
    if ( requestedSortKey ){
      helper.updateSortColumns(component, requestedSortKey, requestedSortKeyType);
    }
  },

  handleRowSelect: function (component, event, helper) {
    document.getSelection().removeAllRanges(); // un-highlights selected text from the multi-select
    if (event.getParam('isMultiSelect')) {
      helper.handleShiftSelect(component, event.getParam('rowId'));
    }
    component.set('v.mostRecentlyToggledRowId', event.getParam('rowId'));
  }
});
