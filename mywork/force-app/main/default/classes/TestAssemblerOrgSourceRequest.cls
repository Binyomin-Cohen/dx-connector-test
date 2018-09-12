@isTest
private class TestAssemblerOrgSourceRequest {


    static testMethod void populatesSourceOAuthInfo() {
        Release__c release = new Release__c(Name='Summer 14');
        insert release;

        Build__c build = TestingUtils.createBuild(release.Id, BuildServices.STATUS_SUCCESS);
        Instances__c instance = TestingUtils.createInstance('dev');

        TestingUtils.createOAuthSettings();
        TestingUtils.setupSightlineAuth();

        Auth_User__c sourceAuthUser = TestingUtils.createAuthUser(UserInfo.getUserId(), instance.Id);
        Auth_User__c targetAuthUser = TestingUtils.createAuthUser(UserInfo.getUserId(), instance.Id);

        sourceAuthUser.Refresh_Token__c = 'Test Source Refresh Token';
        sourceAuthUser.Instance_URL__c = 'Test Source Instance URL';
        targetAuthUser.Refresh_Token__c = 'Test Target Refresh Token';
        targetAuthUser.Instance_URL__c = 'Test Target Instance URL';

        Test.startTest();

            AssemblerOrgSourceRequest testRequest = new AssemblerOrgSourceRequest(build, sourceAuthUser, targetAuthUser, false);

        Test.stopTest();

        System.assertEquals(build.Id, testRequest.buildId, 'The build ID should match.');
        System.assertEquals(sourceAuthUser.Refresh_Token__c, testRequest.sourceRefreshToken, 'The source refresh token should match.');
        System.assertEquals(sourceAuthUser.Instance_URL__c + AssemblerRequest.SOAP_ENDPOINT, testRequest.sourceEndpoint, 'The source endpoint should match.');
    }
}