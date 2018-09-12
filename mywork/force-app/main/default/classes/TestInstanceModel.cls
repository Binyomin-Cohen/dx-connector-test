@isTest
private class TestInstanceModel {
    static testMethod void hasActiveScanJob_inactive() {
        InstanceModel instanceWithNoJob = new InstanceModel(new Instances__c());
        InstanceModel instanceWithBlankJob = new InstanceModel(new Instances__c(), new ALM_Job__c());

        Test.startTest();
            System.assertEquals(false, instanceWithNoJob.hasActiveScanJob, 'hasActiveScanJob should be false when the instance has no Scan Job');
            System.assertEquals(false, instanceWithBlankJob.hasActiveScanJob, 'hasActiveScanJob should be false when the instance has a blank Scan Job');
        Test.stopTest();
    }

    static testMethod void hasActiveScanJob_active() {
        ALM_Job__c scanJob = TestingUtils.buildScanJob(null, null, SCANServices.TOOL_STATUS_SCHEDULED);
        insert scanJob;

        InstanceModel instanceWithActiveJob = new InstanceModel(new Instances__c(), scanJob);

        Test.startTest();
            System.assertEquals(true, instanceWithActiveJob.hasActiveScanJob, 'hasActiveScanJob should be true when the instance has an active Scan Job');
        Test.stopTest();
    }

    static testMethod void initNewScanJob() {

        Instances__c sourceInstance = new Instances__c(Name='dev', Type__c='sandbox');
        Instances__c targetInstance = new Instances__c(Name='alm', Type__c='sandbox', Is_ALM_Instance__c = true);

        insert new List<Instances__c> {sourceInstance, targetInstance};

        InstanceModel instance = new InstanceModel(sourceInstance);
        Test.startTest();

            instance.initNewScanJob();

        Test.stopTest();

        ALM_Job__c scanJob = instance.scanJob;

        System.assertNotEquals(null, scanJob, 'The tool should be set to SCAN');
        System.assertEquals(ALMJobServices.getToolName(ALMJobServices.ToolType.SCAN), scanJob.Tool__c, 'The tool should be set to SCAN');
        System.assertEquals(sourceInstance.Id, scanJob.Source_Instance__c, 'The source instance should be populated with the source instance');
        System.assertEquals(targetInstance.Id, scanJob.Target_Instance__c, 'The target instance should be populated with the ALM instance');
        System.assertEquals(InstanceModel.DEFAULT_COMPONENTS, scanJob.Components__c, 'Components should be initialized to *');
        System.assertEquals(SCANServices.TOOL_STATUS_SCHEDULED, scanJob.Status__c, 'The status should be initialized to Scheduled');

        System.assertEquals(InstanceModel.DEFAULT_SCAN_INTERVAL, scanJob.Interval__c, 'The interval should be initialized to the default interval');
        System.assertEquals(InstanceModel.DEFAULT_SCAN_START_TIME, scanJob.Scheduled_Start_Time__c, 'The scheduled start time should be initialized to the default start time');
        System.assertEquals(InstanceModel.DEFAULT_SCAN_END_TIME, scanJob.Scheduled_End_Time__c, 'The scheduled end time should be initialized to the default end time');
        
        System.assertEquals(true, scanJob.Scheduled_On_Monday__c, 'Monday should be scheduled');
        System.assertEquals(true, scanJob.Scheduled_On_Tuesday__c, 'Tuesday should be scheduled');
        System.assertEquals(true, scanJob.Scheduled_On_Wednesday__c, 'Wednesday should be scheduled');
        System.assertEquals(true, scanJob.Scheduled_On_Thursday__c, 'Thursday should be scheduled');
        System.assertEquals(true, scanJob.Scheduled_On_Friday__c, 'Friday should be scheduled');

        System.assertEquals(false, instance.isScanDeactivationPending, 'SCAN deactivation should not be pending on initialization of a new SCAN job.');
    }

    static testMethod void scanResult_valid() {
        // Set up attributes for instance application result.
        DateTime startTime = DateTime.now();
        DateTime endTime = startTime.addMinutes(1);
        String testResult = 'Success';

        // Set up the test instance.
        Instances__c testInstance = new Instances__c(Name='Test Instance');
        insert testInstance;

        ALM_Application_Result__c applicationResult = TestingUtils.createAlmApplicationResult(startTime, endTime, testResult, testResult, testInstance.Id, ALMJobServices.ToolType.SCAN);

        test.startTest();
            InstanceModel.ScanResult scanResult = new InstanceModel.ScanResult(applicationResult);
        test.stopTest();

        System.assertNotEquals(null, scanResult, 'The scan result should not be null.');
        System.assertEquals(testInstance.Id, scanResult.instanceId, 'The instance ID should be constructed properly.');
        System.assertEquals(endTime.format(), scanResult.lastRunTime, 'The last run time should be constructed properly.');
        System.assertEquals(testResult, scanResult.result, 'The result should be constructed properly.');
        System.assertEquals(applicationResult.Id, scanResult.record.Id, 'The application result record should be constructed properly.');
    }

    static testMethod void scanResult_noApplicationResult() {
        // Set up a test instance ID.
        String testInstanceId = 'Test Instance ID';

        Test.startTest();
            InstanceModel.ScanResult scanResult = new InstanceModel.ScanResult(testInstanceId);
        Test.stopTest();

        System.assertNotEquals(null, scanResult, 'A scan result constructed without an application result should still construct and not be null.');
        System.assertEquals(testInstanceId, scanResult.instanceId, 'A scan result constructed without an application result should initialize its instance ID to the ID provided.');
        System.assertEquals('N/A', scanResult.lastRunTime, 'A scan result constructed without an application result should initialize its last run time to "N/A".');
        System.assertEquals('-', scanResult.result, 'A scan result constructed without an application result should initialize its result to "-".');
    }

    static testMethod void scanResult_nullRunTime() {

        ALM_Application_Result__c result = new ALM_Application_Result__c();
        
        Test.startTest();
            InstanceModel.ScanResult scanResult = new InstanceModel.ScanResult(result);
        Test.stopTest();

        System.assertEquals('', scanResult.lastRunTime, 'A scan result constructed without a run time should set the last run time to an empty string.');
    }

    static testMethod void checkIsRenameLocked_nullRecord() {
        Long expirationTime = DateTime.now().addHours(1).getTime();

        Instances__c instance = new Instances__c(Rename_Lock_Expiration_Time__c=expirationTime);
        insert instance;

        InstanceModel model = new InstanceModel(instance);

        delete instance;

        Boolean locked = null;
        Test.startTest();
            try {
                locked = model.checkIsRenameLocked();
            } catch (Exception e) {
                System.assert(false, 'No exceptions should be thrown.');
            }
        Test.stopTest();

        System.assertEquals(false, locked, 'The instance should be marked as unlocked when the record does not exist.');
    }

    static testMethod void checkIsRenameLocked_locked_Fresh() {
        Long expirationTime = DateTime.now().addHours(1).getTime();

        Instances__c instance = new Instances__c(Rename_Lock_Expiration_Time__c=expirationTime);
        insert instance;

        InstanceModel model = new InstanceModel(instance);

        Boolean locked = null;
        Test.startTest();
            try {
                locked = model.checkIsRenameLocked();
            } catch (Exception e) {
                System.assert(false, 'No exceptions should be thrown.');
            }
        Test.stopTest();

        System.assertEquals(true, locked, 'The instance should be marked as locked.');
    }

    static testMethod void checkIsRenameLocked_locked_Expired() {
        Long expirationTime = DateTime.now().addHours(-1).getTime();

        Instances__c instance = new Instances__c(Rename_Lock_Expiration_Time__c=expirationTime);
        insert instance;

        InstanceModel model = new InstanceModel(instance);

        Boolean locked = null;
        Test.startTest();
            try {
                locked = model.checkIsRenameLocked();
            } catch (Exception e) {
                System.assert(false, 'No exceptions should be thrown.');
            }
        Test.stopTest();

        System.assertEquals(false, locked, 'The instance should be marked as unlocked due to an expired lock.');
    }

    static testMethod void checkIsRenameLocked_unlocked() {
        Instances__c instance = new Instances__c(Rename_Lock_Expiration_Time__c=null);
        insert instance;

        InstanceModel model = new InstanceModel(instance);

        Boolean locked = null;
        Test.startTest();
            try {
                locked = model.checkIsRenameLocked();
            } catch (Exception e) {
                System.assert(false, 'No exceptions should be thrown.');
            }
        Test.stopTest();

        System.assertEquals(false, locked, 'The instance should be marked as unlocked.');
    }

    static testMethod void setRenameLock() {
        Instances__c instance = new Instances__c(Rename_Lock_Expiration_Time__c=null);
        insert instance;

        InstanceModel model = new InstanceModel(instance);

        Test.startTest();
            try {
                model.setRenameLock();
            } catch (Exception e) {
                System.assert(false, 'No exceptions should be thrown.');
            }
        Test.stopTest();

        System.assertEquals(true, model.checkIsRenameLocked(), 'The instance should successfully lock for renaming.');
    }

    static testMethod void clearRenameLock() {
        Instances__c instance = new Instances__c(Rename_Lock_Expiration_Time__c=DateTime.now().addHours(1).getTime());
        insert instance;

        InstanceModel model = new InstanceModel(instance);

        Test.startTest();
            try {
                model.clearRenameLock();
            } catch (Exception e) {
                System.assert(false, 'No exceptions should be thrown.');
            }
        Test.stopTest();

        System.assertEquals(false, model.checkIsRenameLocked(), 'The instance should successfully unlock for renaming.');
    }
}