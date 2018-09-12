({
  doInit : function(component, event, helper) {
    var dependenciesCol = helper.buildSortableColumn('Dependency', 'dependency');
    dependenciesCol['infoText'] =
      'A dependency is created when a component needs another component to be valid. ' +
      'This column will show both dependent and referenced components. ' +
      'Dependent components e.g. an object and a field. Referenced Components ' +
      'e.g. an object referenced in an apex class';

    component.set('v.columns', [
      helper.buildSortableColumn('Instance', 'environment'),
      helper.buildSortableColumn('Name', 'componentName'),
      helper.buildSortableColumn('Type', 'componentType'),
      helper.buildSortableColumn('Parent Component', 'parentComponentName'),
      helper.buildSortableTypedColumn('Last Modified Date', 'lastModifiedDate', 'datetime'),
      helper.buildSortableColumn('Last Modified By', 'lastModifiedBy'),
      dependenciesCol
    ]);
  }

});
