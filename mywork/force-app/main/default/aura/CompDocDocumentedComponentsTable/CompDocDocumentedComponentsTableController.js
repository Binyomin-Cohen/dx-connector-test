({
  doInit : function(component, event, helper) {
    var excludedColumns = component.get('v.excludeColumns'),
        cols = [];

    if (!excludedColumns.instance) {
      cols.push(helper.buildSortableColumn('Instance', 'environment'));
    }
    if (!excludedColumns.name) {
      cols.push(helper.buildSortableColumn('Name', 'componentName'));
    }
    if (!excludedColumns.type) {
      cols.push(helper.buildSortableColumn('Type', 'componentType'));
    }
    if (!excludedColumns.parentComponent) {
      cols.push(helper.buildSortableColumn('Parent Component', 'parentComponentName'));
    }
    if (!excludedColumns.lastModifiedDate) {
      cols.push(helper.buildSortableTypedColumn('Last Modified Date', 'lastModifiedDate', 'datetime'));
    }
    if (!excludedColumns.lastModifiedBy) {
      cols.push(helper.buildSortableColumn('Last Modified By', 'lastModifiedBy'));
    }
    if (!excludedColumns.notes) {
      cols.push(helper.buildSortableColumn('Notes', 'notes'));
    }
    if (!excludedColumns.deployManually) {
      cols.push(helper.buildSortableTypedColumn('Deploy Manually', 'deployManually', 'boolean'));
    }
    component.set('v.columns', cols);
  },

});
