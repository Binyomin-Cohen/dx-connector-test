/**
 * This class represents the deserialized JSON of the Field_Modified_Data__c field on the Component__c object.
 */ 
public with sharing class FieldModifiedData {
    public String environmentName { get; set; }
    public Datetime lastModifiedDate { get; private set; }
    public String lastModifiedByName { get; private set; }
    public Datetime createdDate { get; private set; }
    public String createdByName { get; private set; }
    public Boolean deleted { get; private set; }
    
    public FieldModifiedData(String environmentName, Datetime lastModifiedDate, String lastModifiedByName, Datetime createdDate, String createdByName) {
    	this.environmentName = environmentName;
        this.lastModifiedDate = lastModifiedDate;
        this.lastModifiedByName = lastModifiedByName;
        this.createdDate = createdDate;
        this.createdByName = createdByName;
    }

    public FieldModifiedData(String environmentName, Datetime lastModifiedDate, String lastModifiedByName, Datetime createdDate, String createdByName, Boolean deleted) {
        this.environmentName = environmentName;
        this.lastModifiedDate = lastModifiedDate;
        this.lastModifiedByName = lastModifiedByName;
        this.createdDate = createdDate;
        this.createdByName = createdByName;
        this.deleted = deleted;
    }
    
    public FieldModifiedData(String environmentName) {
    	this.environmentName = environmentName;
    }

    public FieldModifiedData(String environmentName, Boolean deleted) {
        this.environmentName = environmentName;
        this.deleted = deleted;
    }
}