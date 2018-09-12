@isTest
private class TestAssemblerGitSourceRequest {

    static testMethod void populatesSourceOAuthInfo() {
        final String TEST_PUBLIC_KEY = 'Test Public Key';
        final String TEST_PRIVATE_KEY = 'Test Private Key';
        final String TEST_PASSPHRASE = 'Test Passphrase';

        Release__c release = new Release__c(Name='Summer 14');
        insert release;

        Instances__c instance = TestingUtils.createInstance('dev');

        TestingUtils.createOAuthSettings();
        TestingUtils.setupSightlineAuth();

        Auth_User__c targetAuthUser = TestingUtils.createAuthUser(UserInfo.getUserId(), instance.Id);
        targetAuthUser.Instance_URL__c = 'Test Target Instance URL';

        Id userId = UserInfo.getUserId();
        SSHServices.storePublicKey(userId, TEST_PUBLIC_KEY);
        SSHServices.storePrivateKey(userId, TEST_PRIVATE_KEY);
        SSHServices.storePassphrase(userId, TEST_PASSPHRASE);

        VC_Repository__c repo = TestingUtils.createVcRepository('git-repo', 'http://www.git.com', 'GitHub', 'GitTest');
        repo.SFDC_Metadata_Path__c = 'some/src/path/';

        Build__c build = TestingUtils.createBuild(release.Id, BuildServices.STATUS_NOT_STARTED);
        build.Source_Repository_Location__c = 'master';
        build.Source_Repository__c = repo.Id;

        Test.startTest();
            AssemblerGitSourceRequest assemblerRequest = new AssemblerGitSourceRequest(build, targetAuthUser, repo, false);
        Test.stopTest();

        VersionControlSource vcSource = assemblerRequest.versionControlSource;

        System.assertNotEquals(null, vcSource, 'The version control source info should be populated');
        System.assertEquals(TEST_PUBLIC_KEY, vcSource.publicKey, 'The public key should be set on the version control source ');
        System.assertEquals(TEST_PRIVATE_KEY, vcSource.privateKey, 'The private key should be set on the version control source ');
        System.assertEquals(TEST_PASSPHRASE, vcSource.passphrase, 'The passphrase key should be set on the version control source ');
        System.assertEquals(repo.Id, vcSource.repoId, 'The repo id should be set on the version control source ');
        System.assertEquals(repo.Repository_URL__c, vcSource.repoUrl, 'The repo url should be set on the version control source ');
        System.assertEquals(repo.SFDC_Metadata_Path__c, vcSource.sfdcMetadataPath, 'The metadata path should be set on the version control source ');
        System.assertEquals(build.Source_Repository_Location__c, vcSource.repoLocation, 'The repo location should be set on the version control source ');
    }
}