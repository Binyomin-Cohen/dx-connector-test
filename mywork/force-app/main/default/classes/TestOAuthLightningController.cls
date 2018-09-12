@isTest
private class TestOAuthLightningController {

    private static Instances__c setupInstanceAndAuthSettings() {
        TestingUtils.createOAuthSettings();
        final String SANDBOX_INSTANCE_TYPE = 'Sandbox';
        Instances__c instance = new Instances__c(Name='dev');
        instance.Type__c = SANDBOX_INSTANCE_TYPE;
        insert instance;
        return instance;
    }

    static testMethod void oAuthCacheRecordHasCorrectInProgressStatus() {
        Instances__c instance = setupInstanceAndAuthSettings();

        Test.startTest();

            OAuthLightningController.auraAuthorizeInstance(instance.Id, false);

        Test.stopTest();

        Boolean authIsInProgress = OAuthServices.OAuthRequestIsInProgress(instance.Id, UserInfo.getUserId());
        System.assert(authIsInProgress, 'The cache record should indicate that the job is in progress');
    }

    static testMethod void auraAuthorizeInstance_isForTools() {
        Instances__c instance = setupInstanceAndAuthSettings();

        Test.startTest();
            Boolean isForTools = true;
            String authUrl = OAuthLightningController.auraAuthorizeInstance(instance.Id, isForTools);
        Test.stopTest();

        Map<String, String> state = getStateMapFromAuthURL(authUrl);
        String redirectURL = state.get('origin_url');
        System.assertEquals(true, redirectURL.endsWith(Page.OAuthRedirectHandlerTools.getUrl()), 'When isForTools is set the user should be redirected to the tools auth page');
    }

    private static testMethod void testAuraAuthorizeInstance_isNotForTools() {
        Instances__c instance = setupInstanceAndAuthSettings();

        String expectedRedirectHandlerUrl = URL.getSalesforceBaseUrl().toExternalForm()
            + Page.OAuthRedirectHandler.getUrl();

        Test.startTest();
            String actualAuthorizeUrl = OAuthLightningController.auraAuthorizeInstance(instance.Id, false);
        Test.stopTest();

        System.assert(String.IsNotBlank(actualAuthorizeUrl), 'The auth url should not be empty');

        PageReference actualUrlPageReference = new PageReference(actualAuthorizeUrl);
        Map<String, String> params = actualUrlPageReference.getParameters();

        System.assertEquals(true, actualUrlPageReference.getUrl().startsWith('https://test.salesforce.com' + OAuthRequest.OAUTH_CODE_END_POINT_URL), 'The oauth endpoint should be set properly');
        System.assertEquals(true, params.containsKey('state'), 'A state parameter should be included');
        System.assertEquals(true, params.containsKey('grant_type'), 'A grant_type parameter should be included');
        System.assertEquals(true, params.containsKey('display'), 'A display parameter should be included');

        System.assertEquals('popup', params.get('display'), 'The parameter should be set correctly');
        System.assertEquals(OAuthRequest.AUTH_GRANT_TYPE_CODE, params.get('grant_type'), 'The grant_type parameter should be set to the authorization code value');

        Map<String, Object> state = (Map<String, Object>)JSON.deserializeUntyped(params.get('state'));
        System.assertEquals(true, state.containsKey('origin_url'), 'An origin_url should be included in the state parameter');
        System.assertEquals(expectedRedirectHandlerUrl, state.get('origin_url'),'The origin url should be correctly set');
    }

    static Map<String, String> getStateMapFromAuthURL(String authUrl) {
        PageReference authRef = new PageReference(authUrl);
        Map<String, String> state = (Map<String, String>)JSON.deserialize(
                authRef.getParameters().get('state'), Map<String, String>.class);
        return state;
    }

    private static testMethod void auraAuthorizeInstance_noInstanceIdThrowsException() {
        Test.setMock(HttpCalloutMock.class, new MockWebAssemblerAPI(MockWebAssemblerAPI.LOG_ACTION));
        String instanceId = '';
        Boolean isForTools = true;

        Test.startTest();
            try {
                OAuthLightningController.auraAuthorizeInstance(instanceId, isForTools);
                System.assert(false, 'An exception should have been thrown');
            } catch (Exception e) {
                System.assert(e instanceof AuraHandledException,
                              'An AuraHandledException should have been thrown.');
            }
        Test.stopTest();

        List<Logged_Exception__c> exceptions = [SELECT Id, Application__c, Exception_Description__c
                                                FROM Logged_Exception__c];
        System.assertEquals(1, exceptions.size(), 'An exception should have been logged');

        Logged_Exception__c e = exceptions[0];
        System.assertEquals(String.valueOf(ALMLogServices.Application.OAUTH), e.Application__c,
                            'The log application should be correct');
        System.assert(e.Exception_Description__c.toLowerCase().contains('instance'),
                     'The message should mention the instance');

    }
}
