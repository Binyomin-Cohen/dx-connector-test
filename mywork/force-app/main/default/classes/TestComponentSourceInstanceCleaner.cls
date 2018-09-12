@isTest
private class TestComponentSourceInstanceCleaner {
    static testMethod void cleanComponentSources_deletedInstancesDetected() {
        final String ACTIVE_INSTANCE_NAME = 'testActive1';
        final String ACTIVE_INSTANCE_NAME_2 = 'testActive2';
        final String DELETED_INSTANCE_NAME = 'test2';

        Instances__c activeInstance = TestingUtils.createInstance(ACTIVE_INSTANCE_NAME);
        Instances__c activeInstance2 = TestingUtils.createInstance(ACTIVE_INSTANCE_NAME_2);
        Instances__c deletedInstance = TestingUtils.buildInstance(DELETED_INSTANCE_NAME);
        deletedInstance.Is_Deleted__c = true;
        insert deletedInstance;

        Component__c testComponentAllActiveInstances = TestingUtils.buildComponent('TestComp1', null, null);
        testComponentAllActiveInstances.Source_Instances__c = String.Join(
                    new List<String>{ACTIVE_INSTANCE_NAME,
                                     ACTIVE_INSTANCE_NAME_2}, ';'
                );

        Component__c testComponentWithADeletedInstance = TestingUtils.buildComponent('TestComp2', null, null);
        testComponentWithADeletedInstance.Source_Instances__c = String.Join(
                    new List<String>{ACTIVE_INSTANCE_NAME,
                                     ACTIVE_INSTANCE_NAME_2,
                                     DELETED_INSTANCE_NAME}, ';'
                );

        List<Component__c> testComponents = new List<Component__c>{testComponentAllActiveInstances, testComponentWithADeletedInstance};
        insert testComponents;
        Set<String> expectedInstanceNames = New Set<String>{ACTIVE_INSTANCE_NAME, ACTIVE_INSTANCE_NAME_2};

        Test.startTest();
            Database.executeBatch(new ComponentSourceInstanceCleaner());
        Test.stopTest();

        Map<Id, Component__c> actualComponents = new Map<Id, Component__c>([SELECT Id, Source_Instances__c from Component__c]);
        System.assertEquals(testComponents.size(), actualComponents.size(), 'The correct number of components should exist');

        for(Component__c testComponent : testComponents) {
            System.assert( actualComponents.containsKey(testComponent.Id), 'The component should exist');
            System.assert(String.IsNotEmpty(testComponent.Source_Instances__c), 'The source instances picklist should be populated' );

            Component__c actualComponent = actualComponents.get(testComponent.Id);

            Set<String> actualInstanceNameSet = new Set<String>(actualComponent.Source_Instances__c.split(';'));
            System.assertEquals( expectedInstanceNames, actualInstanceNameSet, 'The component should have the correct instance names');
        }
    }
}
