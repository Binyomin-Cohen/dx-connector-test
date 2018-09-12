({
  buildColumn : function(columnLabel, sortKey){
    return {label : columnLabel, styleClass : columnLabel.replace(" ", "-").toLowerCase(), sortKey : sortKey};
  },

  buildSortableColumn : function(columnLabel, sortKey ){
    return {label : columnLabel, styleClass : 'sorting', sortKey : sortKey, dataType : 'string' };
  },

  buildSortableTypedColumn : function(columnLabel, sortKey, sortKeyType ){
    return {label : columnLabel, styleClass : 'sorting', sortKey : sortKey, dataType : sortKeyType };
  },

  updateSortColumns : function(component, requestedSortKey, requestedSortKeyType){
    var currentSortKey = component.get('v.currentSortKey');
    if (currentSortKey == requestedSortKey){
      this.toggleSortDirection(component);
    } else {
      component.set('v.currentSortKeyType', requestedSortKeyType);
      component.set('v.currentSortKey', requestedSortKey);
    }
  },

  toggleSortDirection : function(component){
    var currentSortDirection = component.get('v.currentSortDirection');
    component.set('v.currentSortDirection', currentSortDirection == 'desc' ? 'asc' : 'desc' );
  },

  findRow : function(component, rowKey) {
    var rows = component.get("v.currentPageDependentComponents"),
        row;
    for(var i = 0; i <  rows.length; i++) {
      row = rows[i];
      if (row.key === rowKey) return row;
    }
    return null;
  },

  /** Retrieves a list of rows between rowKey1 and rowKey2. The order of rowKey1 and rowKey2 does not matter.
   *  Returns an empty list if no rows are found.
   */
  getRowsInRange : function(rows, rowKey1, rowKey2) {
    var foundRowKey1 = false,
        foundRowKey2 = false,
        rowsInRange = [],
        row;

    for (var i = 0; i < rows.length; i++) {
      row = rows[i];
      foundRowKey1 = (foundRowKey1 || row.key === rowKey1);
      foundRowKey2 = (foundRowKey2 || row.key === rowKey2);

      if (foundRowKey1 || foundRowKey2) {
        rowsInRange.push(row);
      }
      if (foundRowKey1 && foundRowKey2){
        break;
      }
    }
    // only return rows if a valid range has been found
    return (foundRowKey1 && foundRowKey2) ? rowsInRange : [];
  },

  handleShiftSelect : function(component, shiftClickedRowKey) {
    var rows = component.get('v.currentPageDependentComponents'),
        previouslyClickedRowKey = component.get("v.mostRecentlyToggledRowId");

    if (!previouslyClickedRowKey) {
      return;
    }

    var rowsToMultiSelect = this.getRowsInRange(rows, previouslyClickedRowKey, shiftClickedRowKey),
        previouslyClickedRow = this.findRow(component, previouslyClickedRowKey),
        newCheckedStatus;
    if (rowsToMultiSelect.length > 0 && previouslyClickedRow && typeof previouslyClickedRow.checked === 'boolean') {
      newCheckedStatus = previouslyClickedRow.checked;

      rowsToMultiSelect.forEach(function(row) {
        row.checked = newCheckedStatus;
      });
      component.set('v.currentPageDependentComponents', rows); // forces table rerender
    }
  }

});
