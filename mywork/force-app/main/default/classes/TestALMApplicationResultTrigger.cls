@isTest
private class TestALMApplicationResultTrigger {

    static Instances__c instance;

    static void setup() {
        instance = new Instances__c(Name='dev', Type__c='Production / Developer');
        insert instance;
    }

    static testMethod void testCacheProfileTemplate() {

        setup();

        Component__c component1 = TestingUtils.createComponent('class 1', 'Apex Class', instance.Id);
        Component__c component2 = TestingUtils.createComponent('class 2', 'Apex Class', instance.Id);

        ALM_Application_Result__c scanResult = TestingUtils.createAlmApplicationResult(DateTime.now(), null, '', '', instance.Id, ALMJobServices.ToolType.SCAN);
        Test.startTest();
            ALMApplicationResultServices.TRIGGER_HAS_RUN = false;
            scanResult.Result__c = SCANServices.SUCCESS_STATUS;
            update scanResult;
            Integer futureCallsMade = Limits.getFutureCalls();
        Test.stopTest();

        ProfileTemplate.ProfileTemplateState cachedState = new ProfileTemplate.ProfileTemplateState(instance.Name);
        ProfileServices.getCache().getData( cachedState );

        ProfileTemplate profileTemplate = cachedState.getTemplate();

        System.assertEquals(instance.Name, profileTemplate.instanceName, 'The instance name should be set on the profile template');

        List<Profile_Permission_Data__mdt> categories = ProfileServices.getProfilePermissionData(true);
        System.assertEquals(categories.size(), profileTemplate.sections.size(), 'The number of sections in the template should equal the number of profile categories');

        Map<String, ProfileTemplate.Section> nameToCategory = new Map<String, ProfileTemplate.Section>();
        for (ProfileTemplate.Section category : profileTemplate.sections) {
            nameToCategory.put(category.label, category);
        }

        System.assertEquals(true, nameToCategory.containsKey('Apex Class Access'), 'There should be a category for apex classes');

        ProfileTemplate.Section apexSection = nameToCategory.get('Apex Class Access');

        System.assertEquals(2, apexSection.permissions.size(), 'There should be a permission for each apex component in this instance');
        System.assertEquals(2, futureCallsMade, 'Two future calls should be made, one to the components and the other to refresh the profile template cache.');
    }

    static testMethod void testCacheProfileTemplate_succeessWithWarnings() {
        setup();

        ALM_Application_Result__c scanResult = TestingUtils.createAlmApplicationResult(DateTime.now(), null, '', '', instance.Id, ALMJobServices.ToolType.SCAN);
        Test.startTest();
            ALMApplicationResultServices.TRIGGER_HAS_RUN = false;
            scanResult.Result__c = SCANServices.SUCCESS_WITH_WARNINGS_STATUS;
            update scanResult;
        Test.stopTest();

        ProfileTemplate.ProfileTemplateState cachedState = new ProfileTemplate.ProfileTemplateState(instance.Name);

        try {
            ProfileServices.getCache().getData( cachedState );
        } catch(State.StateException se) {
            System.assert(false, 'The profile template should be cached after setting the status to success with warnings');
        }
        System.assert(true, 'The profile template should be cached after setting the status to success with warnings');
    }

    static testMethod void populateInstanceRuntimeInCache_InstanceDoesNotExist() {
        List<ALM_Application_Result__c> allALMApplicationResults = new List<ALM_Application_Result__c>();

        String INSTANCE_1_NAME = 'Instance1';
        String INSTANCE_2_NAME = 'Instance2';
        String INSTANCE_3_NAME = 'Instance3';

        Instances__c instance1 = TestingUtils.createInstance(INSTANCE_1_NAME);
        Instances__c instance2 = TestingUtils.createInstance(INSTANCE_2_NAME);

        DateTime now = DateTime.now();
        ALM_Application_Result__c result1 = TestingUtils.createAlmApplicationResult(now, now.addMinutes(2), SCANServices.FAILURE_STATUS, SCANServices.FAILURE_STATUS, instance1.Id, ALMJobServices.ToolType.SCAN);
        ALM_Application_Result__c result2 = TestingUtils.createAlmApplicationResult(now, now.addMinutes(3), SCANServices.FAILURE_STATUS, SCANServices.FAILURE_STATUS, instance2.Id, ALMJobServices.ToolType.SCAN);
        result1.Result__c = SCANServices.SUCCESS_STATUS;
        result2.Result__c = SCANServices.SUCCESS_STATUS;
        update new List<ALM_Application_Result__c>{result1, result2};

        //Construct the cache
        ComponentDocController.getFormData();

        //Create the additional instance and build the additional app results
        Instances__c instance3 = TestingUtils.createInstance(INSTANCE_3_NAME);
        ALM_Application_Result__c result3 = TestingUtils.createAlmApplicationResult(now, now.addMinutes(6), SCANServices.FAILURE_STATUS, SCANServices.FAILURE_STATUS, instance3.Id, ALMJobServices.ToolType.SCAN);
        ALM_Application_Result__c result4 = TestingUtils.createAlmApplicationResult(now, now.addMinutes(5), SCANServices.FAILURE_STATUS, SCANServices.FAILURE_STATUS, instance2.Id, ALMJobServices.ToolType.SCAN);
        ALM_Application_Result__c result5 = TestingUtils.createAlmApplicationResult(now, now.addMinutes(10), SCANServices.FAILURE_STATUS, SCANServices.FAILURE_STATUS, instance2.Id, ALMJobServices.ToolType.SCAN);
        result3.Result__c = SCANServices.SUCCESS_WITH_WARNINGS_STATUS;
        result4.Result__c = SCANServices.SUCCESS_WITH_WARNINGS_STATUS;
        result5.Result__c = SCANServices.SUCCESS_WITH_WARNINGS_STATUS;

        Map<String, String> expectedTimesMap = new Map<String, String>{
            INSTANCE_1_NAME => now.addMinutes(2).format(),
            INSTANCE_2_NAME => now.addMinutes(10).format(),
            INSTANCE_3_NAME => now.addMinutes(6).format()
        };

        Test.startTest();
            ALMApplicationResultServices.TRIGGER_HAS_RUN = false;
            update new List<ALM_Application_Result__c>{result3, result4, result5};
        Test.stopTest();

        TestComponentDocController.assertInstanceRunTimes(expectedTimesMap, ComponentDocServices.getRunTimes());
    }

    static testMethod void populateInstanceRuntimeInCache_CacheDoesNotExist() {
        List<ALM_Application_Result__c> allALMApplicationResults = new List<ALM_Application_Result__c>();

        String INSTANCE_1_NAME = 'Instance1';
        String INSTANCE_2_NAME = 'Instance2';
        String INSTANCE_3_NAME = 'Instance3';

        Instances__c instance1 = TestingUtils.createInstance(INSTANCE_1_NAME);
        Instances__c instance2 = TestingUtils.createInstance(INSTANCE_2_NAME);

        DateTime now = DateTime.now();
        ALM_Application_Result__c result1 = TestingUtils.createAlmApplicationResult(now, now.addMinutes(2), SCANServices.FAILURE_STATUS, SCANServices.FAILURE_STATUS, instance1.Id, ALMJobServices.ToolType.SCAN);
        ALM_Application_Result__c result2 = TestingUtils.createAlmApplicationResult(now, now.addMinutes(3), SCANServices.FAILURE_STATUS, SCANServices.FAILURE_STATUS, instance2.Id, ALMJobServices.ToolType.SCAN);
        result1.Result__c = SCANServices.SUCCESS_STATUS;
        result2.Result__c = SCANServices.SUCCESS_STATUS;

        Test.startTest();
            update new List<ALM_Application_Result__c>{result1, result2};
        Test.stopTest();

        System.assertEquals(null, ALMApplicationResultServices.loadPageState().getInstanceTimes(), 'No cache should exist');
    }

    static testMethod void refreshComponentsInCache() {
        Instances__c instance = TestingUtils.createInstance('instance');

        List<Component__c> components = new List<Component__c>();
        for (Integer count = 0; count < 10; count++) {
            components.add(TestingUtils.buildComponent('comp' + count, 'type', instance.Id));
        }
        insert components;

        DateTime now = DateTime.now();
        ALM_Application_Result__c almResult = TestingUtils.createAlmApplicationResult(
                now, now.addMinutes(2), SCANServices.FAILURE_STATUS,
                SCANServices.FAILURE_STATUS, instance.Id, ALMJobServices.ToolType.SCAN);
        almResult.Result__c = SCANServices.SUCCESS_STATUS;

        System.assert(ComponentDocServices.getCachedRecentlyModifiedComponents().isEmpty(),
                'The cache should be empty right now.');

        Test.startTest();
            ALMApplicationResultServices.TRIGGER_HAS_RUN = false;
            update almResult;
        Test.stopTest();

        Set<Id> componentIds = new Map<Id, Component__c>(components).keySet();
        List<Id> cachedComponentIds = ComponentDocServices.getCachedRecentlyModifiedComponents();

        System.assertEquals(components.size(), cachedComponentIds.size(),
                'The cache size should match the number of components that were created.');
        System.assertEquals(componentIds, new Set<Id>(cachedComponentIds),
                'The cached component Ids should match the Ids of the components that were created.');
    }

    static testMethod void copyMailToField() {
        String SUCCESS = 'Success';
        String FAILURE = 'Failure';
        String RUNNING = 'Running';
        String QUEUED = 'Queued';
        
        String successEmail = 'success@success.com';
        String failureEmail = 'failure@failure.com';
        String runningEmail = '';
        String queuedEmail = 'queued@queued.com';
        
        ALM_Job__c successJob = new ALM_Job__c(Status__c=SUCCESS, Mail_To__c=successEmail);
        ALM_Job__c failureJob = new ALM_Job__c(Status__c=FAILURE, Mail_To__c=failureEmail);
        ALM_Job__c runningJob = new ALM_Job__c(Status__c=RUNNING, Mail_To__c=runningEmail);
        ALM_Job__c queuedJob = new ALM_Job__c(Status__c=QUEUED, Mail_To__c=queuedEmail);
        insert new List<ALM_Job__c> {successJob, failureJob, runningJob, queuedJob};
        
        Test.startTest();
            ALM_Application_Result__c successResult = new ALM_Application_Result__c(ALM_Job__c=successJob.Id, Result__c=SUCCESS);
            ALM_Application_Result__c failureResult = new ALM_Application_Result__c(ALM_Job__c=failureJob.Id, Result__c=FAILURE);
            ALM_Application_Result__c runningResult = new ALM_Application_Result__c(ALM_Job__c=runningJob.Id, Result__c=RUNNING);
            ALM_Application_Result__c queuedResult = new ALM_Application_Result__c(ALM_Job__c=queuedJob.Id, Result__c=QUEUED);
        
            insert new List<ALM_Application_Result__c> {successResult, failureResult, runningResult, queuedResult};
        Test.stopTest();
        
        List<ALM_Application_Result__c> results = [SELECT Result__c, Mail_To__c 
                                                   FROM ALM_Application_Result__c];
        
        for (ALM_Application_Result__c result : results) {
            String expectedEmail;
            if (result.Result__c == SUCCESS) {
                expectedEmail = successEmail;
            } else if (result.Result__c == FAILURE) {
                expectedEmail = failureEmail;
            } else if (result.Result__c == RUNNING) {
                expectedEmail = null;
            } else if (result.Result__c == QUEUED) {
                expectedEmail = queuedEmail;
            }
            
            System.assertEquals(expectedEmail, result.Mail_To__c, 
                'The email address on the ALM Job record should be copied to the ALM Application Result');
        }
    }
    
    static testMethod void refreshComponentsInCache_updateCache() {
        ComponentDocServices.RECENTLY_MODIFIED_COMPONENTS_CACHE_LIMIT = 10;
        Instances__c instance = TestingUtils.createInstance('instance');
        DateTime now = DateTime.now();

        String modifiedComponentName = 'modifiedComponent';
        String componentType = 'type';

        List<Component__c> components = new List<Component__c>();
        Component__c modifiedComponent = new Component__c(
                Name = modifiedComponentName,
                Full_Name__c = modifiedComponentName,
                Type__c = componentType,
                Instance__c = instance.Id
        );
        modifiedComponent.Overall_Last_Modified_Date__c = now.addHours(1);
        components.add(modifiedComponent);

        for (Integer count = 0; count < ComponentDocServices.RECENTLY_MODIFIED_COMPONENTS_CACHE_LIMIT; count++) {
            components.add(TestingUtils.buildComponent('comp' + count, componentType, instance.Id));
        }
        insert components;

        ALM_Application_Result__c almResult = TestingUtils.createAlmApplicationResult(
                now, now.addMinutes(2), SCANServices.FAILURE_STATUS,
                SCANServices.FAILURE_STATUS, instance.Id, ALMJobServices.ToolType.SCAN);
        almResult.Result__c = SCANServices.SUCCESS_STATUS;

        ComponentDocServices.cacheRecentlyModifiedComponents(new List<Id>(
                new Map<Id, Component__c>(
                        [SELECT Id, Overall_Last_Modified_Date__c
                         FROM Component__c
                         ORDER BY Overall_Last_Modified_Date__c DESC NULLS LAST, Id DESC
                         LIMIT :ComponentDocServices.RECENTLY_MODIFIED_COMPONENTS_CACHE_LIMIT]
                ).keySet()
        ));

        List<Id> preScanCachedIds = ComponentDocServices.getCachedRecentlyModifiedComponents();

        System.assertEquals(ComponentDocServices.RECENTLY_MODIFIED_COMPONENTS_CACHE_LIMIT, preScanCachedIds.size(),
                'The cache should contain ' + ComponentDocServices.RECENTLY_MODIFIED_COMPONENTS_CACHE_LIMIT + ' Ids.');
        System.assert(new Set<Id>(preScanCachedIds).contains(modifiedComponent.Id),
                'The cache should contain modifiedComponent.');

        modifiedComponent.Overall_Last_Modified_Date__c = null;
        update modifiedComponent;

        Test.startTest();
            ALMApplicationResultServices.TRIGGER_HAS_RUN = false;
            update almResult;
        Test.stopTest();

        List<Id> postScanCachedIds = ComponentDocServices.getCachedRecentlyModifiedComponents();

        System.assertEquals(ComponentDocServices.RECENTLY_MODIFIED_COMPONENTS_CACHE_LIMIT, postScanCachedIds.size(),
                        'The cache should still contain ' + ComponentDocServices.RECENTLY_MODIFIED_COMPONENTS_CACHE_LIMIT + ' Ids.');
        System.assertEquals(false, new Set<Id>(postScanCachedIds).contains(modifiedComponent.Id),
                'The cache should contain no longer contain modifiedComponent.');
    }
}