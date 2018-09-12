@isTest
private class TestAdminAlmSettingsController {
    static testMethod void loadState_clearsPageMessages() {
        TestingUtils.createOAuthSettings();
        Test.setMock(HttpCalloutMock.class, new MockOAuthAPI(MockOAuthAPI.SUCCESS_ACCESS_TOKEN_REQUEST));

        Instances__c devInstance = new Instances__c(Name='dev', Type__c='sandbox');
        devInstance.Is_ALM_Instance__c = true;
        insert devInstance;

        TestingUtils.createAuthUser(TestingUtils.ADMIN_USER.Id, devInstance.Id, true);

        AdminAlmSettingsController controller = new AdminAlmSettingsController();
        controller.pageMessages = new List<PageMessage>{new PageMessage(
            ApexPages.Severity.ERROR, 'a message'
        )};

        Map<String,String> state = new Map<String, String>{
            OAuthController.INSTANCE_STATE_PARAM => devInstance.Id,
            OAuthController.CSRF_STATE_PARAM => OAuthServices.generateCSRFToken()
        };

        PageReference ref = Page.AdminInstanceManagement;
        ref.getParameters().put('code', 'somecode');
        ref.getParameters().put('state', JSON.serialize(state));
        Test.setCurrentPage(ref);

        Test.startTest();

            controller.handleOAuthRedirect();

        Test.stopTest();

        System.assertEquals(true, controller.pageMessages.isEmpty(), 'Page messages should be cleared out when going through the oauth flow successfully');
    }

    static testMethod void checkAuthUser_valid() {
        Instances__c almInstance = new Instances__c(Name='ALM Instance', Type__c='Production/Developer', Is_ALM_Instance__c=true);
        insert almInstance;

        Auth_User__c authUser = new Auth_User__c(Instance__c=almInstance.Id, Is_For_Tools__c=true, Org_Id__c=UserInfo.getOrganizationId(), Is_Refresh_Token_Valid__c=true);
        insert authUser;

        AdminAlmSettingsController controller = new AdminAlmSettingsController();
        controller.pageMessages.clear();

        Test.startTest();
            controller.checkAuthUser();
        Test.stopTest();

        System.assert(controller.pageMessages.isEmpty(), 'A valid check should result in no page messages.');
    }

    static testMethod void checkAuthUser_invalid_noALMInstance() {
        Auth_User__c authUser = new Auth_User__c(Is_For_Tools__c=true, Org_Id__c=UserInfo.getOrganizationId());
        insert authUser;

        AdminAlmSettingsController controller = new AdminAlmSettingsController();
        controller.pageMessages.clear();

        Test.startTest();
            controller.checkAuthUser();
        Test.stopTest();

        System.assert(controller.pageMessages.isEmpty(), 'A missing ALM instance should result in no check and no page messages.');
    }

    static testMethod void checkAuthUser_invalid_noAuthUser() {
        Instances__c almInstance = new Instances__c(Name='ALM Instance', Type__c='Production/Developer', Is_ALM_Instance__c=true);
        insert almInstance;

        AdminAlmSettingsController controller = new AdminAlmSettingsController();
        controller.pageMessages.clear();

        Test.startTest();
            controller.checkAuthUser();
        Test.stopTest();

        System.assert(controller.pageMessages.isEmpty(), 'A missing auth user should result in no check and no page messages.');
    }

    static testMethod void checkAuthUser_invalid_wrongAuthUser() {
        Instances__c almInstance = new Instances__c(Name='ALM Instance', Type__c='Production/Developer', Is_ALM_Instance__c=true);
        insert almInstance;

        Auth_User__c authUser = new Auth_User__c(Instance__c=almInstance.Id, Is_For_Tools__c=true, Org_Id__c='00D000000000000');
        insert authUser;

        AdminAlmSettingsController controller = new AdminAlmSettingsController();
        controller.pageMessages.clear();

        Test.startTest();
            controller.checkAuthUser();
        Test.stopTest();

        System.assertEquals(1, controller.pageMessages.size(), 'An auth user authorized for an instance that does not match the current org should result in an invalid check and a page message.');
    }

    private static final String testInstanceName = 'Test Instance Name';
    private static final String testInstanceType = 'Test Instance Type';
    private static final String testInstanceCustomDomain = 'https://www.example.com';
    private static final Map<String, Object> testPageStateMap = new Map<String, Object>{
        'name' => testInstanceName,
        'type' => testInstanceType,
        'domain' => testInstanceCustomDomain
    };

    private static testMethod void getCurrentPageStateMap() {
        AdminAlmSettingsController testController = new AdminAlmSettingsController();

        Test.startTest();

            testController.almInstanceModel.record.Name = testInstanceName;
            testController.almInstanceModel.record.Type__c = testInstanceType;
            testController.almInstanceModel.record.Custom_Domain__c = testInstanceCustomDomain;

            Map<String, Object> actualPageStateMap = testController.getCurrentPageStateMap();

        Test.stopTest();

        System.assertEquals(testInstanceName, actualPageStateMap.get('name'), 'The instance name should be retrieved properly.');
        System.assertEquals(testInstanceType, actualPageStateMap.get('type'), 'The instance type should be retrieved properly.');
        System.assertEquals(testInstanceCustomDomain, actualPageStateMap.get('domain'), 'The instance custom domain should be retrieved properly.');
    }

    private static testMethod void restorePageState() {
        State.store(new PageState(AdminAlmSettingsController.PAGE_STATE_TOKEN, testPageStateMap));

        AdminAlmSettingsController testController = new AdminAlmSettingsController();

        Test.startTest();

            testController.restorePageState();

        Test.stopTest();

        System.assertEquals(testInstanceName, testController.almInstanceModel.record.Name, 'The instance name should be restored properly.');
        System.assertEquals(testInstanceType, testController.almInstanceModel.record.Type__c, 'The instance type should be restored properly.');
        System.assertEquals(testInstanceCustomDomain, testController.almInstanceModel.record.Custom_Domain__c, 'The instance custom domain should be restored properly.');
    }

    private static testMethod void savePageState() {
        AdminAlmSettingsController testController = new AdminAlmSettingsController();

        Test.startTest();

            testController.almInstanceModel.record.Name = testInstanceName;
            testController.almInstanceModel.record.Type__c = testInstanceType;
            testController.almInstanceModel.record.Custom_Domain__c = testInstanceCustomDomain;

            testController.savePageState();

        Test.stopTest();

        PageState actualPageState = new PageState(AdminAlmSettingsController.PAGE_STATE_TOKEN);
        State.retrieve(actualPageState);

        System.assertEquals(3, actualPageState.stateMap.size(), 'The proper number of state elements should be saved properly.');
        System.assertEquals(testInstanceName, actualPageState.stateMap.get('name'), 'The instance name should be saved properly.');
        System.assertEquals(testInstanceType, actualPageState.stateMap.get('type'), 'The instance type should be saved properly.');
        System.assertEquals(testInstanceCustomDomain, actualPageState.stateMap.get('domain'), 'The instance custom domain should be saved properly.');
    }

    private static testMethod void loadPageState() {
        State.store(new PageState(AdminAlmSettingsController.PAGE_STATE_TOKEN, testPageStateMap));

        Test.startTest();

            Map<String, Object> actualPageStateMap = new AdminAlmSettingsController().loadPageState();

        Test.stopTest();

        System.assertEquals(testPageStateMap.size(), actualPageStateMap.size(), 'The proper number of state elements should be loaded properly.');
        System.assertEquals(testInstanceName, actualPageStateMap.get('name'), 'Instance name should be loaded properly.');
        System.assertEquals(testInstanceType, actualPageStateMap.get('type'), 'Instance type should be loaded properly.');
        System.assertEquals(testInstanceCustomDomain, actualPageStateMap.get('domain'), 'Instance custom domain should be loaded properly.');
    }

    private static testMethod void expirePageState() {
        PageState testPageState = new PageState(AdminAlmSettingsController.PAGE_STATE_TOKEN);

        State.store(testPageState);

        System.assertEquals(1, [SELECT Count() FROM State__c WHERE Token__c = :testPageState.getStateToken()], 'The page state should exist.');

        Test.startTest();

            new AdminAlmSettingsController().expirePageState();

        Test.stopTest();

        System.assertEquals(0, [SELECT Count() FROM State__c WHERE Token__c = :testPageState.getStateToken()], 'The page state should not exist.');
    }
}