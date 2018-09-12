@isTest
private class TestInstanceServices {
    static testMethod void getLoginEndpoint_production() {
        Instances__c instance = new Instances__c(Type__c='Production / Developer');
        System.assertEquals('https://login.salesforce.com', InstanceServices.getLoginEndpoint(instance), 'Production instances should use login.salesforce.com as the endpoint');
    }

    static testMethod void getLoginEndpoint_sandbox() {
        Instances__c instance = new Instances__c(Type__c='Sandbox');
        System.assertEquals('https://test.salesforce.com', InstanceServices.getLoginEndpoint(instance), 'Sandbox instances should use test.salesforce.com as the endpoint');
    }

    static testMethod void getLoginEndpoint_custom() {
        Instances__c instance = new Instances__c(Type__c='Production / Developer', Custom_Domain__c='bluewolf.my.salesforce.com');
        System.assertEquals('https://' + instance.Custom_Domain__c, InstanceServices.getLoginEndpoint(instance), 'Instances with custom domains should use that domain as the endpoint');
    }

    static testMethod void getLoginEndpoint_custom_with_protocol() {
        Instances__c instance = new Instances__c(Type__c='Production / Developer', Custom_Domain__c='https://bluewolf.my.salesforce.com');
        System.assertEquals(instance.Custom_Domain__c, InstanceServices.getLoginEndpoint(instance), 'Instances with custom domains should use that domain as the endpoint');
    }

    static testMethod void getVisualforceDomain() {
        String domain = 'https://bluewolf--c.na38.visual.force.com';
        String url = domain + '/apex/PageName?q=param';
        System.assertEquals(domain, InstanceServices.getVisualforceDomain(url), 'Visualforce urls should just return the domain');
    }

    static testMethod void getVisualforceDomain_lightningUrl() {
        String domain = 'https://talisdev2-dev-ed.lightning.force.com';
        String url = domain + '/aura?r=17';
        System.assertEquals('https://talisdev2-dev-ed.visual.force.com', InstanceServices.getVisualforceDomain(url), 'lightning urls should return the visualforce domain');
    }

    static testMethod void getInstanceModel_noResults() {
        Test.startTest();
            InstanceModel actual = InstanceServices.getInstanceModel('badid');
        Test.stopTest();

        System.assertEquals(null, actual, 'No records should be returned when an invalid id is entered');
    }

    static testMethod void getInstanceModel() {
        Instances__c instance = new Instances__c(Name='Test Instance', Type__c='Sandbox');
        insert instance;

        Test.startTest();
            InstanceModel instanceModel = InstanceServices.getInstanceModel(instance.Id);
        Test.stopTest();

        System.assertEquals(instance.Id, instanceModel.id, 'The record searched for should be returned');
    }

    static testMethod void getInstanceByName_No_Match() {
        Instances__c instance = new Instances__c(Name='Test Instance', Type__c='Sandbox');
        insert instance;

        String instanceName = 'Foo';

        Test.startTest();
            InstanceModel actual = InstanceServices.getInstanceByName(instanceName);
        Test.stopTest();

        System.assertEquals(null, actual, 'No matching instance should return NULL');
    }

    static testMethod void getInstanceByName_Match_Found() {
        String instanceName = 'Foo';

        Instances__c instance = new Instances__c();
        instance.Name = instanceName;
        instance.Type__c = 'Sandbox';
        insert instance;

        Test.startTest();
            InstanceModel actual = InstanceServices.getInstanceByName(instanceName);
        Test.stopTest();

        System.assertEquals(instanceName, actual.name, 'The returned instance name should match the name requested.');
    }

    static testMethod void addNewInstance_valid() {
        String instanceName = 'Test_In stan-ce';
        String instanceType = 'Production / Developer';
        Boolean caught = false;

        InstanceModel model = new InstanceModel(new Instances__c());
        model.record.Name = instanceName;
        model.record.Type__c = instanceType;

        Test.startTest();
            try {
                InstanceServices.addNewInstance(model);
            } catch(ALMException e) {
                caught = true;
            }
        Test.stopTest();

        System.assertEquals(false, caught, 'The new instance should be added normally.');
    }

    static testMethod void addNewInstance_badNameLength_and_special_chars() {
        String instanceNameShort = '';
        String instanceNameLong = 'ThisInstanceNameIsMostDefinitelyFarTooLongForTheFieldWidth';
        String instanceNameSpecialChars = 'ThisInstance|sSpecial';
        String instanceType = 'Sandbox';

        InstanceModel modelShort = new InstanceModel(new Instances__c());
        modelShort.record.Name = instanceNameShort;
        modelShort.record.Type__c = instanceType;

        InstanceModel modelLong = new InstanceModel(new Instances__c());
        modelLong.record.Name = instanceNameLong;
        modelLong.record.Type__c = instanceType;

        InstanceModel modelSpecialChars = new InstanceModel(new Instances__c());
        modelSpecialChars.record.Name = instanceNameSpecialChars;
        modelSpecialChars.record.Type__c = instanceType;

        Test.startTest();
            try {
                InstanceServices.addNewInstance(modelShort);
                System.assert(false, 'Short instance name should throw an exception.');
            } catch(ALMException e) {
                System.assert(true, 'Short instance name should throw an exception.');
            }

            try {
                InstanceServices.addNewInstance(modelLong);
                System.assert(false, 'Long instance name should throw an exception.');
            } catch(ALMException e) {
                System.assert(true, 'Long instance name should throw an exception.');
            }

            try {
                InstanceServices.addNewInstance(modelSpecialChars);
                System.assert(false, 'Special chars in instance name should throw an exception.');
            } catch(ALMException e) {
                System.assert(true, 'Special chars in instance name should throw an exception.');
            }
        Test.stopTest();
    }

    static testMethod void addNewInstance_duplicateAdd() {
        String instanceName = 'TestInstance';
        String instanceType = 'Production / Developer';

        InstanceModel model = new InstanceModel(new Instances__c());
        model.record.Name = instanceName;
        model.record.Type__c = instanceType;
        model.record.Is_Deleted__c = false;

        Test.startTest();
            try {
                InstanceServices.addNewInstance(model);
                InstanceServices.addNewInstance(model);
                System.assert(false, 'Duplicate instance adds should throw an exception.');
            } catch(ALMException e) {
                System.assert(true, 'Duplicate instance adds should throw an exception.');
                System.assertEquals(System.Label.Instance_Add_Error + InstanceServices.ERROR_INSTANCE_NAME_UNIQUE, e.getMessage(), 'Duplicate instance add exception message should be correct.');
            }
        Test.stopTest();
    }

    static testMethod void getAlmInstance_noALMInstance() {
        System.assertEquals(null, InstanceServices.almInstance, 'The ALM Instance should be null when an instance does not exist with the Is ALM Instnace flag set');
    }

    static testMethod void getAlmInstance() {
        Instances__c targetInstance = new Instances__c(Name='alm', Type__c='sandbox', Is_ALM_Instance__c = true);
        insert targetInstance;

        Test.startTest();
            System.assertEquals(targetInstance.Id, InstanceServices.almInstance.Id, 'The ALM Instance should be returned');
        Test.stopTest();
    }

    static testMethod void fetchScanResult_validSingleInstance() {
        // Set up the test instance.
        Instances__c testInstance = new Instances__c(Name='Test Instance');
        insert testInstance;

        // Set up an application result for the test instance.
        DateTime startTime = DateTime.now();
        DateTime endTime = startTime.addMinutes(1);
        ALM_Application_Result__c testApplicationResult = TestingUtils.createAlmApplicationResult(startTime, endTime, 'Success', 'Success', testInstance.Id, ALMJobServices.ToolType.SCAN);

        // Set up the SCAN result for the test instance.
        InstanceModel.ScanResult testScanResult = new InstanceModel.ScanResult(testApplicationResult);

        // Retrieve SCAN results for the valid instances.
        Test.startTest();
            Map<String, InstanceModel.ScanResult> scanResults = InstanceServices.fetchScanResult(new List<String>{ testInstance.Id });
        Test.stopTest();

        System.assertEquals(1, scanResults.size(), 'There should be a single instance ID/SCAN result pair returned for a single instance.');
        System.assert(scanResults.containsKey(testInstance.Id), 'The returned map should contain a SCAN result for the test instance.');
        System.assertEquals(testScanResult.lastRunTime, scanResults.get(testInstance.Id).lastRunTime, 'The SCAN result run times for the test instance should match.');
        System.assertEquals(testScanResult.result, scanResults.get(testInstance.Id).result, 'The SCAN results for the test instance should match.');
    }

    static testMethod void fetchScanResult_validMultipleInstances() {
        // Set up run times for instance SCAN jobs.
        DateTime startTime = DateTime.now();
        DateTime endTime = startTime.addMinutes(1);

        // Set up the first test instance.
        Instances__c testInstance0 = new Instances__c(Name='Test Instance 0');
        insert testInstance0;

        // Set up an application result for the first test instance.
        ALM_Application_Result__c testApplicationResult = TestingUtils.createAlmApplicationResult(startTime, endTime, 'Success', 'Success', testInstance0.Id, ALMJobServices.ToolType.SCAN);

        // Set up the SCAN result for the first test instance.
        InstanceModel.ScanResult testScanResult0 = new InstanceModel.ScanResult(testApplicationResult);

        // Set up the second test instance.
        Instances__c testInstance1 = new Instances__c(Name='Test Instance 1');
        insert testInstance1;

        // Set up an application result for the second test instance.
        testApplicationResult = TestingUtils.createAlmApplicationResult(startTime, endTime, 'Success', 'Success', testInstance1.Id, ALMJobServices.ToolType.SCAN);

        // Set up the SCAN result for the second test instance.
        InstanceModel.ScanResult testScanResult1 = new InstanceModel.ScanResult(testApplicationResult);

        // Retrieve SCAN results for the valid instances.
        Test.startTest();
            Map<String, InstanceModel.ScanResult> scanResults = InstanceServices.fetchScanResult(new List<String>{ testInstance0.Id, testInstance1.Id });
        Test.stopTest();

        System.assertEquals(2, scanResults.size(), 'There should be two instance ID/SCAN result pairs returned for two instances.');
        System.assert(scanResults.containsKey(testInstance0.Id), 'The returned map should contain a SCAN result for the first test instance.');
        System.assertEquals(testScanResult0.lastRunTime, scanResults.get(testInstance0.Id).lastRunTime, 'The SCAN result run times for the first test instance should match.');
        System.assertEquals(testScanResult0.result, scanResults.get(testInstance0.Id).result, 'The SCAN results for the first test instance should match.');
        System.assert(scanResults.containsKey(testInstance1.Id), 'The returned map should contain a SCAN result for the second test instance.');
        System.assertEquals(testScanResult1.lastRunTime, scanResults.get(testInstance1.Id).lastRunTime, 'The SCAN result run times for the second test instance should match.');
        System.assertEquals(testScanResult1.result, scanResults.get(testInstance1.Id).result, 'The SCAN results for the second test instance should match.');
    }

    static testMethod void fetchScanResult_invalidID() {
        String invalidInstanceId = 'Invalid Instance ID';

        // Attempt to retrieve SCAN results for the invalid instance.
        Test.startTest();
            Map<String, InstanceModel.ScanResult> scanResults = InstanceServices.fetchScanResult(new List<String>{ invalidInstanceId });
        Test.stopTest();

        System.assertNotEquals(null, scanResults, 'When given an invalid instance ID, the returned SCAN results collection should still not be null.');
        System.assertEquals(0, scanResults.size(), 'When given an invalid instance ID, the returned SCAN results collection should be of size 0.');
        System.assertEquals(null, scanResults.get(invalidInstanceId), 'When given an invalid instance ID, no SCAN results should be associated with the bad ID.');
    }

    static testMethod void softDeleteInstance_initialization() {
        String testName = 'Test Instance';
        Instances__c testInstance = new Instances__c(Name=testName);
        insert testInstance;

        List<Instances__c> instanceResults = [SELECT Name, Is_Deleted__c FROM Instances__c WHERE Name=:testName LIMIT 1];
        System.assertEquals(false, instanceResults.isEmpty(), 'The instance should be found.');
        System.assertEquals(false, instanceResults[0].Is_Deleted__c, 'The instance should initialize to not be soft-deleted.');
    }

    static testMethod void softDeleteInstance_byId_valid() {
        String testName = 'Test Instance';
        TestingUtils.createInstance(testName);

        Boolean success;
        Test.startTest();
            success = InstanceServices.softDeleteInstance([SELECT Is_Deleted__c FROM Instances__c WHERE Name=:testName LIMIT 1][0].Id);
        Test.stopTest();

        System.assert(success, 'The deletion should return a successful result.');
        List<Instances__c> instanceResults = [SELECT Is_Deleted__c FROM Instances__c WHERE Name=:testName LIMIT 1];
        System.assertEquals(false, instanceResults.isEmpty(), 'The instance should be found.');
        System.assert(instanceResults[0].Is_Deleted__c, 'The instance should be soft-deleted.');
    }

    static testMethod void softDeleteInstance_byId_badId() {
        String testName = 'Test Instance';
        TestingUtils.createInstance(testName);

        Boolean success;
        Test.startTest();
            success = InstanceServices.softDeleteInstance(Id.valueOf(Instances__c.SObjectType.getDescribe().getKeyPrefix() + '000000000000'));
        Test.stopTest();

        System.assertEquals(false, success, 'The deletion should return a failure result.');
        List<Instances__c> instanceResults = [SELECT Is_Deleted__c FROM Instances__c WHERE Name=:testName LIMIT 1];
        System.assertEquals(false, instanceResults.isEmpty(), 'The instance should be found.');
        System.assertEquals(false, instanceResults[0].Is_Deleted__c, 'The instance should not be soft-deleted.');
    }

    static testMethod void softDeleteInstance_byInstance_valid() {
        String testName = 'Test Instance';
        TestingUtils.createInstance(testName);

        Boolean success;
        Test.startTest();
            success = InstanceServices.softDeleteInstance([SELECT Is_Deleted__c FROM Instances__c WHERE Name=:testName LIMIT 1][0]);
        Test.stopTest();

        System.assert(success, 'The deletion should return a successful result.');
        List<Instances__c> instanceResults = [SELECT Is_Deleted__c FROM Instances__c WHERE Name=:testName LIMIT 1];
        System.assertEquals(false, instanceResults.isEmpty(), 'The instance should be found.');
        System.assert(instanceResults[0].Is_Deleted__c, 'The instance should be soft-deleted.');
    }

    static testMethod void softDeleteInstance_byInstance_null() {
        String testName = 'Test Instance';
        TestingUtils.createInstance(testName);

        Instances__c otherInstance = null;

        Boolean success;
        Test.startTest();
            success = InstanceServices.softDeleteInstance(otherInstance);
        Test.stopTest();

        System.assertEquals(false, success, 'The deletion should return a failure result.');
        List<Instances__c> instanceResults = [SELECT Is_Deleted__c FROM Instances__c WHERE Name=:testName LIMIT 1];
        System.assertEquals(false, instanceResults.isEmpty(), 'The instance should be found.');
        System.assertEquals(false, instanceResults[0].Is_Deleted__c, 'The instance should not be soft-deleted.');
    }

    static testMethod void getAllInstances_exludingSoftDeleted() {
        Instances__c instance0 = TestingUtils.createInstance('Test Instance 0');
        Instances__c instance1 = TestingUtils.createInstance('Test Instance 1');

        instance1.Is_Deleted__c = true;
        update instance1;

        Test.startTest();
            List<Instances__c> instances = InstanceServices.getAllInstances();
        Test.stopTest();

        System.assertEquals(1, instances.size(), 'There should only be one instance returned.');
        System.assertEquals(instance0.Id, instances[0].id, 'Only the instance which has not been deleted should be returned.');
    }

    static testMethod void updateInstanceName() {
        Instances__c instance = TestingUtils.createInstance('Old Instance');

        String newName = 'New Instance Name';

        Test.startTest();
            Boolean result = InstanceServices.updateInstanceName(instance, newName);
        Test.stopTest();

        System.assert(result, 'The update method should return success');
        List<Instances__c> instanceResults = [SELECT Name FROM Instances__c WHERE Name=:newName];

        System.assertEquals(1, instanceResults.size(), 'The instance should be found.');
        System.assertEquals(newName, instanceResults[0].Name, 'The instance name should have been updated.');
    }

    static testMethod void updateInstanceName_InstanceAlreadyExists() {
        String newName = 'Instance1';

        Instances__c instance1 = TestingUtils.createInstance(newName);
        Instances__c instance2 = TestingUtils.createInstance('Instance2');

        Test.startTest();
            try {
                InstanceServices.updateInstanceName(instance2, newName.toLowerCase());
                System.assert(false, 'An ALMException should have been thrown');
            } catch (ALMException e) {
                System.assert(true, 'An exception should have been thrown when a duplicate instance name is detected.');
            }
        Test.stopTest();
    }

    static testMethod void populateInstanceRuntimeInCache_InstanceDoesNotExist() {
        List<ALM_Application_Result__c> allALMApplicationResults = new List<ALM_Application_Result__c>();

        String INSTANCE_1_NAME = 'Instance1';
        String INSTANCE_2_NAME = 'Instance2';
        String INSTANCE_3_NAME = 'Instance3';

        Instances__c instance1 = TestingUtils.createInstance(INSTANCE_1_NAME);
        Instances__c instance2 = TestingUtils.createInstance(INSTANCE_2_NAME);

        DateTime now = DateTime.now();
        TestingUtils.createAlmApplicationResult(now, now.addMinutes(2), 'SuCCesS', 'Success', instance1.Id, ALMJobServices.ToolType.SCAN);
        TestingUtils.createAlmApplicationResult(now, now.addMinutes(3), 'SuCCesS', 'Success', instance2.Id, ALMJobServices.ToolType.SCAN);
        //Construct the cache
        ComponentDocController.getFormData();

        //Create the additional instance and build the additional app results
        Instances__c instance3 = TestingUtils.createInstance(INSTANCE_3_NAME);
        TestingUtils.createAlmApplicationResult(now, now.addMinutes(6), 'SuCCesS', 'Success', instance3.Id, ALMJobServices.ToolType.SCAN);
        TestingUtils.createAlmApplicationResult(now, now.addMinutes(5), 'SuCCesS', 'Success', instance2.Id, ALMJobServices.ToolType.SCAN);

        Map<String, String> expectedTimesMap = new Map<String, String>{
            INSTANCE_1_NAME => now.addMinutes(2).format(),
            INSTANCE_2_NAME => now.addMinutes(5).format(),
            INSTANCE_3_NAME => now.addMinutes(6).format()
        };

        allALMApplicationResults = [SELECT Id, Instance__r.Name, Run_Time__c, Result__c, Instance__r.Id from ALM_Application_Result__c];

        Test.startTest();
            Map<Id, ALMApplicationResultServices.InstanceWithLatestAndSuccessfulRunTime> updatedTimesMap = InstanceServices.populateCacheWithInstanceRunTimes(allALMApplicationResults);
        Test.stopTest();

        Map<String, String> updatedTimesMapStringDates = new Map<String, String>();
        for (Id instanceId : updatedTimesMap.keySet()) {
            ALMApplicationResultServices.InstanceWithLatestAndSuccessfulRunTime instanceResult = updatedTimesMap.get(instanceId);
            updatedTimesMapStringDates.put(instanceResult.instanceName, instanceResult.latestSuccessfulRuntime.format());
        }
        TestComponentDocController.assertInstanceRunTimes(expectedTimesMap, updatedTimesMapStringDates);
    }

    @isTest
    private static void populateCacheWithInstanceRunTimes_nullInstanceId() {
        String instanceName = 'Test Instance';
        Instances__c instance = TestingUtils.createInstance(instanceName);
        ALM_Application_Result__c applicationResult = TestingUtils.createAlmApplicationResult(null, null, 'Running', null, instance.Id, ALMJobServices.ToolType.SCAN);

        State.store(new ALMApplicationResultServices.ResultState(
            new Map<Id, ALMApplicationResultServices.InstanceWithLatestAndSuccessfulRunTime>{
                TestingUtils.createFakeSObjectId(Instances__c.SObjectType) => new ALMApplicationResultServices.InstanceWithLatestAndSuccessfulRunTime(instance.Id, instanceName, 'Failure', DateTime.now()
        )}));

        Test.startTest();
            delete instance;
            applicationResult.Result__c = 'Success';
            update applicationResult;
        Test.stopTest();

        ALMApplicationResultServices.ResultState resultState = ALMApplicationResultServices.loadPageState();

        System.assertNotEquals(null, resultState.getInstanceTimes(), 'The application result cache should not be null.');
    }

    static testMethod void checkInstanceNameUniqueness() {

        String EXISTING_INSTANCE_NAME = 'Instance1';
        String UNIQUE_INSTANCE_NAME = 'Instance2';

        Instances__c instance1 = TestingUtils.createInstance(EXISTING_INSTANCE_NAME);
        Instances__c existingInstanceReturned;
        Instances__c uniqueInstanceReturned;

        Test.startTest();
            existingInstanceReturned = InstanceServices.checkInstanceNameUniqueness(EXISTING_INSTANCE_NAME);
            uniqueInstanceReturned = InstanceServices.checkInstanceNameUniqueness(UNIQUE_INSTANCE_NAME);
        Test.stopTest();

        System.assertNotEquals(null, existingInstanceReturned, 'The existing instance should not be null');
        System.assertEquals(instance1.Id, existingInstanceReturned.Id, 'The existing instance should be returned');
        System.assertEquals(false, existingInstanceReturned.Is_Deleted__c, 'The existing instance should not be returned as deleted');
        System.assertEquals(null, uniqueInstanceReturned, 'The no instance should be returned for the unique instance');

    }

    static testMethod void checkInstanceNameUniqueness_instanceIsDeleted() {

        String EXISTING_INSTANCE_NAME = 'Instance1';
        String UNIQUE_INSTANCE_NAME = 'Instance2';

        Instances__c instance1 = TestingUtils.createInstance(EXISTING_INSTANCE_NAME);
        instance1.Is_Deleted__c = true;
        update instance1;

        Instances__c existingInstanceReturned;
        Instances__c uniqueInstanceReturned;

        Test.startTest();
            existingInstanceReturned = InstanceServices.checkInstanceNameUniqueness(EXISTING_INSTANCE_NAME);
            uniqueInstanceReturned = InstanceServices.checkInstanceNameUniqueness(UNIQUE_INSTANCE_NAME);
        Test.stopTest();

        System.assertNotEquals(null, existingInstanceReturned, 'The existing instance should not be null');
        System.assertEquals(instance1.Id, existingInstanceReturned.Id, 'The existing instance should be returned');
        System.assertEquals(true, existingInstanceReturned.Is_Deleted__c, 'The existing instance should be returned as deleted');
        System.assertEquals(null, uniqueInstanceReturned, 'No instance should be returned for the unique instance');

    }

    static testMethod void undeleteInstance() {

        String EXISTING_INSTANCE_NAME = 'Instance1';

        Instances__c testInstance = TestingUtils.createInstance(EXISTING_INSTANCE_NAME);
        testInstance.Is_Deleted__c = true;
        update testInstance;

        Test.startTest();
            InstanceServices.undeleteInstance(testInstance);
        Test.stopTest();

        Instances__c actualInstance = [SELECT Id, Is_Deleted__c FROM Instances__c];
        System.assertEquals(false, actualInstance.Is_Deleted__c, 'The instance should not be deleted');

    }

    static testMethod void undeleteInstance_error() {

        String EXISTING_INSTANCE_NAME = 'Instance1';

        Instances__c testInstance = TestingUtils.buildInstance(EXISTING_INSTANCE_NAME);
        testInstance.Is_Deleted__c = true;

        Test.startTest();
            try{
                InstanceServices.undeleteInstance(testInstance);
                System.assert(false, 'updating a record that does not exist should thrown an exception');
            } catch (ALMException aex) {
                System.assert(aex.getMessage().contains(System.Label.Instance_Undelete_Error), 'The instance undelete exception message should be thrown.');
            }
        Test.stopTest();

        System.assertEquals(0, [SELECT Id, Is_Deleted__c FROM Instances__c].size(), 'No instances should exist');
    }

    static testMethod void getDeletedInstances_noneExist() {
        final String ACTIVE_INSTANCE_NAME = 'testActive1';
        final String ACTIVE_INSTANCE_NAME_2 = 'testActive2';

        Instances__c activeInstance = TestingUtils.createInstance(ACTIVE_INSTANCE_NAME);
        Instances__c activeInstance2 = TestingUtils.createInstance(ACTIVE_INSTANCE_NAME_2);

        Test.startTest();
            Set<String> actualDeletedInstanceNames = InstanceServices.getDeletedInstanceNames();
        Test.stopTest();

        System.assertEquals(0, actualDeletedInstanceNames.size(), 'No Deleted instance names should be returned');
    }

    static testMethod void getDeletedInstances_oneExists() {
        final String ACTIVE_INSTANCE_NAME = 'testActive1';
        final String ACTIVE_INSTANCE_NAME_2 = 'testActive2';
        final String DELETED_INSTANCE_NAME = 'test2';

        Instances__c activeInstance = TestingUtils.createInstance(ACTIVE_INSTANCE_NAME);
        Instances__c activeInstance2 = TestingUtils.createInstance(ACTIVE_INSTANCE_NAME_2);
        Instances__c deletedInstance = TestingUtils.buildInstance(DELETED_INSTANCE_NAME);
        deletedInstance.Is_Deleted__c = true;
        insert deletedInstance;

        Test.startTest();
            Set<String> actualDeletedInstanceNames = InstanceServices.getDeletedInstanceNames();
        Test.stopTest();

        System.assertEquals(1, actualDeletedInstanceNames.size(), 'One Deleted instance name should be returned');
        System.assert(actualDeletedInstanceNames.contains(DELETED_INSTANCE_NAME), 'The correct Deleted instance name should be returned');
    }

    static testMethod void scheduleComponentCleaningForDeletedInstances_deletionDetected() {
        TestingUtils.deleteExistingJobs(new List<String>{
            ComponentSourceInstanceCleaner.SOURCE_INSTANCE_CLEANER_NAME
        });

        final String ACTIVE_INSTANCE_NAME = 'testActive1';
        final String ACTIVE_INSTANCE_NAME_2 = 'testActive2';
        final String DELETED_INSTANCE_NAME = 'test2';

        Instances__c activeInstance = TestingUtils.createInstance(ACTIVE_INSTANCE_NAME);
        Instances__c activeInstance2 = TestingUtils.createInstance(ACTIVE_INSTANCE_NAME_2);
        Instances__c deletedInstance = TestingUtils.createInstance(DELETED_INSTANCE_NAME);
        List<Instances__c> allInstances = new List<Instances__c>{activeInstance, activeInstance2, deletedInstance};

        Map<Id, Instances__c> oldVersionOfInstances = new Map<Id, Instances__c>(allInstances.deepClone(true));

        activeInstance.Name = 'updatedName';
        activeInstance2.Is_Deleted__c = false;
        deletedInstance.Is_Deleted__c = true;

        Test.startTest();
            InstanceServices.scheduleComponentCleaningForDeletedInstances(oldVersionOfInstances, allInstances);
            List<CronTrigger> actualScheduledCleaningJobs = [
                SELECT NextFireTime
                FROM CronTrigger
                WHERE CronJobDetail.Name = :ComponentSourceInstanceCleaner.SOURCE_INSTANCE_CLEANER_NAME
            ];
            System.assertEquals(1, actualScheduledCleaningJobs.size(), 'A single matching job should be scheduled.');
        Test.stopTest();


    }

    static testMethod void scheduleComponentCleaningForDeletedInstances_noDeletionDetected() {
        TestingUtils.deleteExistingJobs(new List<String>{
            ComponentSourceInstanceCleaner.SOURCE_INSTANCE_CLEANER_NAME
        });

        final String ACTIVE_INSTANCE_NAME = 'testActive1';
        final String ACTIVE_INSTANCE_NAME_2 = 'testActive2';
        final String DELETED_INSTANCE_NAME = 'test2';

        Instances__c activeInstance = TestingUtils.createInstance(ACTIVE_INSTANCE_NAME);
        Instances__c activeInstance2 = TestingUtils.createInstance(ACTIVE_INSTANCE_NAME_2);
        List<Instances__c> allInstances = new List<Instances__c>{activeInstance, activeInstance2};
        Map<Id, Instances__c> oldVersionOfInstances = new Map<Id, Instances__c>(allInstances.deepClone(true));

        activeInstance.Name = 'updatedName';
        activeInstance2.Is_Deleted__c = false;

        Test.startTest();
            InstanceServices.scheduleComponentCleaningForDeletedInstances(oldVersionOfInstances, allInstances);
            List<CronTrigger> actualScheduledCleaningJobs = [
                SELECT NextFireTime
                FROM CronTrigger
                WHERE CronJobDetail.Name = :ComponentSourceInstanceCleaner.SOURCE_INSTANCE_CLEANER_NAME
            ];
            System.assertEquals(0, actualScheduledCleaningJobs.size(), 'No matching job should be scheduled.');
        Test.stopTest();

    }
}