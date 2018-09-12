@isTest
private class TestAssemblerManifestRecord {
    private static Instances__c testInstance;
    private static Backlog__c testBacklogItem;
    private static Component__c testComponent;
    private static Backlog_Component__c testBacklogComponent;
    private static Release__c testRelease;
    private static Build__c testBuild;
    private static Build_Component__c testBuildComponent;

    private static void setup() {
        testInstance = TestingUtils.createInstance('Test Instance');
        testBacklogItem = TestingUtils.createBacklogItem();
        testComponent = TestingUtils.createComponent('Test Component', 'Test Type', testInstance.Id);
    }

    private static void setupDocumented() {
        setup();

        testBacklogComponent = new Backlog_Component__c(
            Backlog__c = testBacklogItem.Id,
            Backlog__r = [SELECT Name, Status__c FROM Backlog__c WHERE Id = :testBacklogItem.Id][0],
            Component__c = testComponent.Id,
            Source_Instance__c = testInstance.Id,
            Source_Instance__r = testInstance
        );
        insert testBacklogComponent;

        testRelease = new Release__c();
        testBuild = TestingUtils.createBuild(testRelease.Id, BuildServices.STATUS_NOT_STARTED);

        testBuildComponent = TestingUtils.createDocumentedBuildComponent(testBacklogComponent, testBuild.Id, testInstance.Id);
        testBuildComponent.Backlog_Component__c = testBacklogComponent.Id;
        testBuildComponent.Backlog_Component__r = testBacklogComponent;
        update testBuildComponent;
    }

    private static testMethod void getDocumentedKey_backlogComponent() {
        setupDocumented();

        AssemblerManifestRecord testAssemblerManifestRecord = new AssemblerManifestRecord(testBacklogComponent);

        Test.startTest();

            String documentedKey = testAssemblerManifestRecord.getDocumentedKey();

        Test.stopTest();

        Backlog__c actualBacklogItem = [SELECT Name FROM Backlog__c WHERE Id = :testBacklogItem.Id][0];

        System.assertEquals(testInstance.Name + '|' + testComponent.Id + '|' + actualBacklogItem.Name, documentedKey, 'The documented key should reflect a documented component.');
    }

    private static testMethod void getDocumentedKey_buildComponent() {
        setupDocumented();

        AssemblerManifestRecord testAssemblerManifestRecord = new AssemblerManifestRecord(testBuildComponent);

        Test.startTest();

            String documentedKey = testAssemblerManifestRecord.getDocumentedKey();

        Test.stopTest();

        Backlog__c actualBacklogItem = [SELECT Name FROM Backlog__c WHERE Id = :testBacklogItem.Id][0];

        System.assertEquals(testInstance.Name + '|' + testComponent.Id + '|' + actualBacklogItem.Name, documentedKey, 'The documented key should reflect a documented component.');
    }

    private static testMethod void getDocumentedKey_undocumented() {
        setup();

        String testEnvironment = 'Test Environment';

        ComponentSearchWrapper testComponentSearchWrapper = new ComponentSearchWrapper(testComponent, testEnvironment, '', DateTime.now(), '', false);
        AssemblerManifestRecord testAssemblerManifestRecord = new AssemblerManifestRecord(testComponentSearchWrapper);

        Test.startTest();

            String documentedKey = testAssemblerManifestRecord.getDocumentedKey();

        Test.stopTest();

        Backlog__c actualBacklogItem = [SELECT Name FROM Backlog__c WHERE Id = :testBacklogItem.Id][0];

        System.assertEquals(testEnvironment + '|' + testComponent.Id, documentedKey, 'The documented key should reflect an undocumented component.');
    }

    private static testMethod void initIsRemoved_manualBacklogComponent() {
        setupDocumented();

        Test.startTest();

            AssemblerManifestRecord nonManualRecord = new AssemblerManifestRecord(testBacklogComponent);
            testBacklogComponent.Deploy_Manually__c = true;
            AssemblerManifestRecord manualRecord = new AssemblerManifestRecord(testBacklogComponent);

        Test.stopTest();

        System.assertEquals(false, nonManualRecord.isRemoved, 'Components that are not marked as deploy manually should not be initialized as removed');
        System.assertEquals(false, nonManualRecord.getBuildComponent().Is_Manual_Deployment__c, 
            'Components that are not marked as deploy manually should not have their build component marked as manual');
        System.assertEquals(true, manualRecord.isRemoved, 'Components that are marked as deploy manually should be initialized as removed');
        System.assertEquals(true, manualRecord.getBuildComponent().Is_Manual_Deployment__c, 
            'Components that are marked as deploy manually should have their build component marked as manual');
    }

     private static testMethod void initIsRemoved_deletedBacklogComponent() {
        setupDocumented();

        Test.startTest();

            testBuildComponent.Backlog_Component__c = null;
            testBuildComponent.Backlog_Component__r = null;

            AssemblerManifestRecord manifestRecord = new AssemblerManifestRecord(testBuildComponent);

        Test.stopTest();

        System.assertEquals(true, manifestRecord.isRemoved, 
            'Components with a deleted backlog component should be initialized as removed');
    }

    private static testMethod void initIsRemoved_undocumentedComponent() {
        setup();

        testRelease = new Release__c(Name='Release with undocumented component');
        insert testRelease;
        testBuild = TestingUtils.createBuild(testRelease.Id, BuildServices.STATUS_NOT_STARTED);

        Build_Component__c undocumentedBuildComponent = 
            TestingUtils.createUndocumentedBuildComponent(testComponent, testBuild.Id, testInstance.Name);

        Test.startTest();
            AssemblerManifestRecord undocumentedRecord 
                = new AssemblerManifestRecord(undocumentedBuildComponent);
        Test.stopTest();

        System.assertEquals(false, undocumentedRecord.isRemoved, 
            'Undocumented components should not be initialized as removed');
    }

    private static testMethod void initIsDeletion() {
        setupDocumented();

        Test.startTest();

            testBacklogComponent.Deleted__c = false;
            AssemblerManifestRecord nonDeletedRecord = new AssemblerManifestRecord(testBacklogComponent);

            testBacklogComponent.Deleted__c = true;
            AssemblerManifestRecord deletedRecord = new AssemblerManifestRecord(testBacklogComponent);

        Test.stopTest();

        System.assertEquals(false, nonDeletedRecord.isDeletion, 'Components that are not marked as deleted should not be initialized as deleted');
        System.assertEquals(false, nonDeletedRecord.getBuildComponent().Is_Deletion__c, 'Components that are not marked as deleted should not be initialized as deleted');
        System.assertEquals(true, deletedRecord.isDeletion, 'Components that are marked as deleted should be initialized as deleted');
        System.assertEquals(true, deletedRecord.getBuildComponent().Is_Deletion__c, 'Components that are marked as deleted should be initialized as deleted');
    }

}