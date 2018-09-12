public with sharing class SprintColumnConfig extends ColumnConfig {
    public SprintColumnConfig() {
        super();
        loadColumns();
    }

    private void loadColumns() {
        Map<String, String> statusValueToLabel = SObjectServices.getPicklistValueMap(Schema.SObjectType.Backlog__c.fields.Status__c);

        Map<String, Column> allColumns = new Map<String, Column>();
        for (String status : statusValueToLabel.keySet()) {
            allColumns.put(status, new Column(status, statusValueToLabel.get(status)));
        }
        activeColumns = SprintServices.getLanes();

        addStaticColumns(activeColumns, new List<Column>{ new Column(SprintModel.NOT_STARTED_STATUS) });

        for (Column col : activeColumns) {
            allColumns.remove(col.apiName);
        }

        Set<String> unusedStatuses = allColumns.keySet();
        for (String status : statusValueToLabel.keySet()) {
            if (unusedStatuses.contains(status)) {
                unusedColumns.add(new Column(status, statusValueToLabel.get(status)));
            }
        }
    }
}