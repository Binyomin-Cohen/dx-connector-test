public with sharing class BacklogItemUploadResult {
    // TODO: Determine whether record is required
    @AuraEnabled
    public Upload_Result__c record;
    @AuraEnabled
    public Id successCsvId;
    @AuraEnabled
    public Id failureCsvId;
    @AuraEnabled
    public Decimal numOfErrors;
    @AuraEnabled
    public Decimal numOfRecordsCreated;

    public BacklogItemUploadResult(){
    }

    public BacklogItemUploadResult(Upload_Result__c uploadResult, Id successCsvId, Id failureCSVId){
        this.record = uploadResult;
        this.numOfErrors = uploadResult.Num_of_Errors__c;
        this.numOfRecordsCreated = uploadResult.Num_of_Records_Created__c;
        this.successCsvId = successCsvId;
        this.failureCSVId = failureCSVId;
    }
}
