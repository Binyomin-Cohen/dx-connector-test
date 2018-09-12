@isTest
private with sharing class TestScratchOrgServices {
    static final String EXPECTED_REFRESH_TOKEN = '5Aep8612Xuhpe0phpNaFCtqiSEGDXtAw8HPJgBUE_duOzPoL3SJt3qTYfhRTJ9TfpTHl0C4oLT.4YZneLxhoP_Z';
    static final String EXPECTED_CLIENT_ID = 'SalesforceDevelopmentExperience';
    static final String EXPECTED_CONSUMER_SECRET = '1384510088588713504';
    static final String SFDX_AUTH_URL = 'force://' + EXPECTED_CLIENT_ID + ':' + EXPECTED_CONSUMER_SECRET +':' + EXPECTED_REFRESH_TOKEN + '@dream-innovation-6209-dev-ed.cs64.my.salesforce.com';

    @isTest
    static void getRefreshTokenFromAuthURL() {
        Scratch_Org_Info__c soi = new Scratch_Org_Info__c(
            SFDX_Auth_URL__c = SFDX_AUTH_URL
        );
        Test.startTest();
            String refreshToken = ScratchOrgServices.getRefreshTokenFromAuthUrl(soi);
        Test.stopTest();
        System.assertEquals(EXPECTED_REFRESH_TOKEN ,
            refreshToken, 'The refresh token should be correctly parsed');

    }

    @isTest
    static void testGetClientIdFromAuthURL() {
        Scratch_Org_Info__c soi = new Scratch_Org_Info__c(
            SFDX_Auth_URL__c = SFDX_AUTH_URL
        );
        Test.startTest();
            String clientId = ScratchOrgServices.getClientIdFromAuthUrl(soi);
        Test.stopTest();
        System.assertEquals(EXPECTED_CLIENT_ID,
            clientId, 'The clientId should be correctly parsed');

    }

    @isTest
    static void testGetConsumerSecretFromAuthURL() {
        Scratch_Org_Info__c soi = new Scratch_Org_Info__c(
            SFDX_Auth_URL__c = SFDX_AUTH_URL
        );
        Test.startTest();
            String consumerSecret = ScratchOrgServices.getConsumerSecretFromAuthUrl(soi);
        Test.stopTest();
        System.assertEquals(EXPECTED_CONSUMER_SECRET,
            consumerSecret, 'The consumer secret should be correctly parsed');
    }

    @isTest
    static void getLoginUrl_whenOwnerIsDifferentFromUser_returnsNull() {
        Scratch_Org__c scratchOrg;
        System.runAs(TestingUtils.buildUser(TestingUtils.ADMIN_USER.profileId)) {
            Backlog__c backlogItem = TestingUtils.createBacklogItem();
            scratchOrg = new Scratch_Org__c(Backlog_Item__c = backlogItem.Id);
            insert scratchOrg;

            Scratch_Org_Info__c scratchOrgInfo = new Scratch_Org_Info__c(
                SFDX_Auth_URL__c = SFDX_AUTH_URL,
                Instance_URL__c = 'test.salesforce.com',
                Name = scratchOrg.Id 
            );
            insert scratchOrgInfo;
        }

        Test.startTest();
            String loginUrl = ScratchOrgServices.getLoginUrl(scratchOrg.Id);
        Test.stopTest();
        
        System.assertEquals(null, loginUrl,
            'The login url returned should be null when requested by a user other than the creator');
    }

   
    @isTest
    static void getLoginUrl() {
        TestingUtils.createOAuthSettings();
        Test.setMock(HttpCalloutMock.class, new MockOAuthAPI(MockOAuthAPI.SUCCESS_ACCESS_TOKEN_REQUEST));
        
        Backlog__c backlogItem = TestingUtils.createBacklogItem();
        Scratch_Org__c scratchOrg = new Scratch_Org__c(Backlog_Item__c = backlogItem.Id);
        insert scratchOrg;

        Scratch_Org_Info__c scratchOrgInfo = new Scratch_Org_Info__c(
            SFDX_Auth_URL__c = SFDX_AUTH_URL,
            Instance_URL__c = 'test.salesforce.com',
            Name = scratchOrg.Id 
        );
        insert scratchOrgInfo;

        Test.startTest();
            String loginUrl = ScratchOrgServices.getLoginUrl(scratchOrg.Id);
        Test.stopTest();

        String expectedLoginUrl = scratchOrgInfo.Instance_Url__c + ScratchOrgServices.FRONT_DOOR_URL ;

        System.assertEquals(true, loginUrl.startsWith(expectedLoginUrl),
            'The login url should be returned when requested by the user who created it');
    }
}
