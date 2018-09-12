@isTest
private with sharing class TestAssemblerJenkinsBuildRequest {
    static testMethod void retrieveComponentsToBuild() {
        TestingUtils.createOAuthSettings();
        TestingUtils.setupSightlineAuth();
        TestingUtils.setupSSH();

        Release__c release = new Release__c(Name='Spring 18');
        insert release;

        Instances__c instance = TestingUtils.createInstance('Dev jenkins build request');

        Auth_User__c targetAuthUser = TestingUtils.createAuthUser(UserInfo.getUserId(), instance.Id);

        VC_Repository__c repo = TestingUtils.createVcRepository('git-repo', 'http://www.git.com', 'GitHub', 'GitTest');

        Build__c build = TestingUtils.createBuild(release.Id, BuildServices.STATUS_NOT_STARTED);
        build.Source_Repository_Location__c = 'master';
        build.Source_Repository__c = repo.Id;

        Backlog__c backlogItem = new Backlog__c(Release__c=release.Id);
        insert backlogItem;

        String documentedProfileName = 'git_user_profile';
        TestingUtils.createDocumentedProfile(backlogItem.Id, documentedProfileName, instance.Id);
        Component__c objectComponent =
             TestingUtils.createComponent('Account', ComponentServices.OBJECT_ALM_NAME, instance.Id);

        Backlog_Component__c documentedComponent = TestingUtils.buildDocumentedComponent(backlogItem.Id, objectComponent, instance.Id);
        insert documentedComponent;

        Test.startTest();
            AssemblerJenkinsBuildRequest assemblerRequest 
                = new AssemblerJenkinsBuildRequest(build, targetAuthUser, repo, false);
        Test.stopTest();

        System.assertEquals(2, assemblerRequest.components.size(), 'The object component should be returned in the manifest');
        //skip index 0 as this is a header row
        System.assertEquals(objectComponent.Name, assemblerRequest.components[1][0],
            'Components documented against the release should be returned in the manifest');
        System.assertEquals(objectComponent.Type__c, assemblerRequest.components[1][1],
            'Components documented against the release should be returned in the manifest');

        System.assertEquals(1, assemblerRequest.profiles.size(), 
            'Profiles documented against the release should be included in the request');

        ProfilePermissions savedProfile = assemblerRequest.profiles[0];

        System.assertEquals(documentedProfileName, savedProfile.name, 
            'Profiles documented against the release should be included in the request');


        System.assertEquals(1, savedProfile.sections.size(), 'The object section should be in the profile permissions.');
        System.assertEquals(ProfileServices.OBJECT_API_NAME, savedProfile.sections[0].apiName,
             'The object section should be in the profile permissions.');

        System.assertEquals(1, savedProfile.sections[0].permissions.size(),
             'The documented object permission should be in the profile permissions.');
        System.assertEquals(objectComponent.Name, savedProfile.sections[0].permissions[0],
             'The documented object permission should be in the profile permissions.');
    }
}
