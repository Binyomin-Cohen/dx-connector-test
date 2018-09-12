@isTest
private class TestOAuthRedirectController {

    static testMethod void handleOAuthRedirect_success() {
        Test.setMock(HttpCalloutMock.class, new MockOAuthAPI(MockOAuthAPI.SUCCESS_ACCESS_TOKEN_REQUEST));
        TestingUtils.createOAuthSettings();
        Id currentUserId = UserInfo.getUserId();

        Instances__c instance = new Instances__c(Name='dev');
        insert instance;

        OAuthRedirectController oauthRedirector = new OAuthRedirectController();
        Map<String,String> state = new Map<String, String>{
            OAuthController.INSTANCE_STATE_PARAM => instance.Id,
            OAuthController.CSRF_STATE_PARAM => OAuthServices.generateCSRFToken()
        };

        OAuthServices.putOAuthRequestStatusInCache(instance.Id, currentUserId, true);

        Test.startTest();
            PageReference ref = Page.OAuthRedirectHandler;
            ref.getParameters().put('code', 'somecode');
            ref.getParameters().put('state', JSON.serialize(state));
            Test.setCurrentPage(ref);

            oauthRedirector.handleRedirect();
        Test.stopTest();

        List<Auth_User__c> auths = [SELECT Id, Instance__c, User__c FROM Auth_User__c];

        System.assertEquals(1, auths.size(), 'when the access token request succeeds, an auth records should be created');
        System.assertEquals(instance.Id, auths[0].Instance__c, 'The instance Id should be set on the auth record');
        System.assertEquals(UserInfo.getUserId(), auths[0].User__c, 'The instance Id should be set on the auth record');
        System.assertEquals(false, OAuthServices.OAuthRequestIsInProgress(instance.Id, currentUserId), 'The cache for this instance should be set to completed');

    }
}