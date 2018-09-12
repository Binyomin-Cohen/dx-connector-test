public with sharing class ComponentSystemInfoExt {
    public List<FieldModifiedData> environments {get; private set;}

    public ComponentSystemInfoExt(ApexPages.StandardController stdCon) {
        Component__c component = (Component__c) stdCon.getRecord();

        if (!String.isEmpty(component.Field_Modified_Data__c)) {
            environments = (List<FieldModifiedData>) JSON.deserialize(component.Field_Modified_Data__c, List<FieldModifiedData>.class);
        }
    }
}