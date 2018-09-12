public with sharing class BacklogItemModel {
    public String id {get; set;}
    public String title {get; set;}
    public String name {get; set;}
    public String status {get; set;}
    public String statusLabel {get; set;}
    public String type {get; set;}
    public Decimal value {get; set;}
    public Decimal effort {get; set;}
    public Decimal priority {get; set;}

    public Map<String, String> statusMap {
        get {
            if (statusMap == null) {
                statusMap = SObjectServices.getPicklistValueMap( Schema.sObjectType.Backlog__c.fields.Status__c );
            }
            return statusMap;
        }
        private set;
    }

    public BacklogItemModel(Backlog__c backlog) {
        id           = backlog.Id;
        name         = backlog.Name;
        type         = backlog.RecordType.Name;
        status       = backlog.Status__c;
        statusLabel  = statusMap.containsKey(status) ? statusMap.get(status) : status;
        title        = String.isNotBlank( backlog.Summary__c ) ? backlog.Summary__c : backlog.User_Goal__c;
        effort       = backlog.Dev_Effort__c;
        value        = backlog.Business_Value__c;
        priority     = backlog.Priority__c;
    }
}