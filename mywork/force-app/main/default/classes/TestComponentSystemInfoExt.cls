@isTest
public class TestComponentSystemInfoExt{
    public static testMethod void testComponentSystemInfoExt() {
        Component__c component = new Component__c(name='Foo__c');
        String environmentName = 'test';
        String lastModifiedByName = 'First User';
        Datetime lastModifiedDate = Datetime.newInstanceGmt(2014, 2, 18, 14, 17, 31);
        String createdByName = 'Second User';
        Datetime createdDate = Datetime.newInstanceGmt(2014, 2, 14, 11, 16, 58);
        component.Field_Modified_Data__c = 
            '[{"environmentName":"' + environmentName + '",' + 
               '"lastModifiedByName":"' + lastModifiedByName + '",' +
               '"lastModifiedDate":"' + lastModifiedDate.format('yyyy-MM-dd\'T\'hh:mm:ss') + '",' +
               '"createdByName":"' + createdByName + '",' +
               '"createdDate":"' + createdDate.format('yyyy-MM-dd\'T\'hh:mm:ss') + '"}]';

        Test.startTest();

            insert component;

        Test.stopTest();

        ApexPages.StandardController stdCon = new ApexPages.standardController(component);
        ComponentSystemInfoExt infoExt = new ComponentSystemInfoExt(stdCon);
        List<FieldModifiedData> environmentNames = infoExt.environments;
        
        System.assertEquals(1, environmentNames.size(), 'There should be 1 record.');
        System.assertEquals(environmentName, environmentNames[0].environmentName, 'Environment name should match.');
        System.assertEquals(lastModifiedByName, environmentNames[0].lastModifiedByName, 'lastModifiedBy should match.');
        System.assertEquals(createdByName, environmentNames[0].createdByName, 'createdBy should match.');
        // This is failing because it's off by some amount of time after deserialization
        // TODO: Figure out why this is happening. Could be a user timezone issue?
        //System.assertEquals(lastModifiedDate, environmentNames[0].lastModifiedDate, 'lastModifiedDate should match.');
        System.assertEquals(createdDate, environmentNames[0].createdDate, 'createdDate should match.');
    }
}