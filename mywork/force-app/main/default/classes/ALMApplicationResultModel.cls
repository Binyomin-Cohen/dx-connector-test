public with sharing class ALMApplicationResultModel {
    @AuraEnabled
    public String id {get; set;}
    @AuraEnabled
    public String startTime {get; set;}
    @AuraEnabled
    public String endTime {get; set;}
    @AuraEnabled
    public String duration {get; set;}
    @AuraEnabled
    public String errorCode {get; set;}
    @AuraEnabled
    public String instanceId {get; set;}
    @AuraEnabled
    public String result {get; set;}
    @AuraEnabled
    public ALM_Application_Result__c record {get; set;}
    @AuraEnabled
    public Boolean isSuccess {get; set;}
    @AuraEnabled
    public Boolean isWarnings {get; set;}
    @AuraEnabled
    public Boolean isFailure {get; set;}
    @AuraEnabled
    public Boolean isInProgress {get; set;}

    public ALMApplicationResultModel(ALM_Application_Result__c record) {
        this.id = record.Id;
        this.startTime = (record.Start_Time__c == null) ? null : record.Start_Time__c.format();
        this.endTime = (record.Run_Time__c == null) ? null : record.Run_Time__c.format();
        this.duration = String.valueOf(record.Duration__c);
        this.errorCode = record.Error_Code__c;
        this.instanceId = record.Instance__c;
        this.result = record.Result__c;
        this.record = record;
        this.isSuccess = ScanServices.SUCCESS_STATUS.equalsIgnoreCase(this.result) ? true : false;
        this.isWarnings = ScanServices.SUCCESS_WITH_WARNINGS_STATUS.equalsIgnoreCase(this.result) ? true : false;
        this.isFailure = ScanServices.FAILURE_STATUS.equalsIgnoreCase(this.result) ? true : false;
        this.isInProgress = !this.isSuccess && !this.isWarnings && !this.isFailure;
    }
}