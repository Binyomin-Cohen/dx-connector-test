public with sharing class BacklogPrioritizationColumnConfig extends ColumnConfig {
    
    @TestVisible
    private static Set<String> columnsToExclude = new Set<String>{
    
    };
    public Boolean isCustomBacklogEnabled {
        get {
            return ALMSettings__c.getInstance().Enable_Custom_Backlogs__c;
        }
        private set;
    }
    
    public BacklogPrioritizationColumnConfig() {
        super();
        if (!isCustomBacklogEnabled){
            columnsToExclude.add(SObjectServices.getFullyQualifiedName('Custom_Priority__c'));
        }
        loadColumns();
    }
    
    private void loadColumns() {
        Map<String, Column> allColumns = new Map<String, Column>();
        for (Column field : BacklogItemServices.getFields()) {
            if (!columnsToExclude.contains(field.apiName)){
                allColumns.put( field.apiName, field);
            }
        }
        
        activeColumns = new List<Column>();
        for (Column activeColumn : BacklogItemServices.getPrioritizationFields()){ 
            if (isCustomBacklogEnabled || activeColumn.apiName != SObjectServices.getFullyQualifiedName('Custom_Priority__c')){ 
                activeColumns.add(activeColumn); 
            }
        } 
        
        addStaticColumns(activeColumns,
            new List<Column>{ new Column(Schema.sObjectType.Backlog__c.fields.Priority__c) });

        for (Column field : activeColumns) {
            allColumns.remove( field.apiName);
            if (BacklogItemServices.DEFAULT_COLUMNS.contains(field.apiName)) {
                field.isDefault = true;
            }
        }

        for (String defaultColumnName : BacklogItemServices.DEFAULT_COLUMNS) {
            if (allColumns.containsKey( defaultColumnName )) {
                Column defaultColumn = allColumns.remove( defaultColumnName );
                defaultColumn.isDefault = true;
                activeColumns.add(defaultColumn);
            }
        }

        unusedColumns = allColumns.values();
        unusedColumns.sort();
    }
}