@isTest
private with sharing class TestAuthUserServices {
    static testMethod void filterChangedRefreshToken_valid() {
        Instances__c instance = new Instances__c(Name='Test Instance');
        insert instance;

        List<Auth_User__c> authUsers = new List<Auth_User__c>{
            TestingUtils.buildAuthUser(UserInfo.getUserId(), instance.Id, true),
            TestingUtils.buildAuthUser(UserInfo.getUserId(), instance.Id, true),
            TestingUtils.buildAuthUser(UserInfo.getUserId(), instance.Id, true)
        };

        authUsers[0].Is_Refresh_Token_Valid__c = true;
        authUsers[1].Is_Refresh_Token_Valid__c = false;
        authUsers[2].Is_Refresh_Token_Valid__c = true;

        insert authUsers;

        Map<Id, Auth_User__c> oldIdToAuthUser = new Map<Id, Auth_User__c> (authUsers.deepClone(true));

        authUsers[0].Is_Refresh_Token_Valid__c = false;
        authUsers[1].Is_Refresh_Token_Valid__c = true;

        Test.startTest();
            List <Auth_User__c> changedRecords = AuthUserServices.filterChangedRefreshToken(authUsers, oldIdToAuthUser);
        Test.stopTest();

        Set<Id> changedIds = Pluck.ids(changedRecords);

        System.assertEquals(2, changedIds.size(), 'There should be two changed records in the returned collection.');
        System.assertEquals(true, changedIds.containsAll(new List<Id>{ authUsers[0].Id, authUsers[1].Id }), 'The returned collection should contain all of the expected sObjects.');
    }

    static testMethod void setLoginError_validRefreshToken() {
        Instances__c instance = new Instances__c(Name='Test Instance');
        insert instance;

        Auth_User__c authUser = TestingUtils.buildAuthUser(UserInfo.getUserId(), instance.Id, true);
        authUser.Is_Refresh_Token_Valid__c = true;
        insert authUser;

        ALM_Job__c almJob = TestingUtils.buildScanJob(instance.Id, instance.Id, SCANServices.TOOL_STATUS_SCHEDULED);
        almJob.Login_Error__c = true;
        insert almJob;

        Test.startTest();
            AuthUserServices.setLoginError(new List<Auth_User__c>{ authUser });
        Test.stopTest();

        almJob = [SELECT Login_Error__c FROM ALM_Job__c WHERE Id=:almJob.Id];

        System.assertEquals(false, almJob.Login_Error__c, 'The login error checkbox should be set to false after the refresh token has been validated and updated.');
    }

    static testMethod void setLoginError_invalidRefreshToken() {
        Instances__c instance = new Instances__c(Name='Test Instance');
        insert instance;

        Auth_User__c authUser = TestingUtils.buildAuthUser(UserInfo.getUserId(), instance.Id, true);
        authUser.Is_Refresh_Token_Valid__c = false;
        insert authUser;

        ALM_Job__c almJob = TestingUtils.buildScanJob(instance.Id, instance.Id, SCANServices.TOOL_STATUS_SCHEDULED);
        almJob.Login_Error__c = false;
        insert almJob;

        Test.startTest();
            AuthUserServices.setLoginError(new List<Auth_User__c>{ authUser });
        Test.stopTest();

        almJob = [SELECT Login_Error__c FROM ALM_Job__c WHERE Id=:almJob.Id];

        System.assertEquals(true, almJob.Login_Error__c, 'The login error checkbox should be set to true after the refresh token has been invalidated and updated.');
    }

    static testMethod void setLoginError_bothRefreshTokensChange() {
        Instances__c sourceInstance = new Instances__c(Name='Test Source Instance');
        insert sourceInstance;
        Instances__c targetInstance = new Instances__c(Name='Test Target Instance');
        insert targetInstance;

        Auth_User__c authUserSource = TestingUtils.buildAuthUser(UserInfo.getUserId(), sourceInstance.Id, true);
        authUserSource.Is_Refresh_Token_Valid__c = true;
        insert authUserSource;

        Auth_User__c authUserTarget = TestingUtils.buildAuthUser(UserInfo.getUserId(), targetInstance.Id, true);
        authUserTarget.Is_Refresh_Token_Valid__c = false;
        insert authUserTarget;

        ALM_Job__c almJob = TestingUtils.buildScanJob(sourceInstance.Id, targetInstance.Id, SCANServices.TOOL_STATUS_SCHEDULED);
        almJob.Login_Error__c = false;
        insert almJob;

        Test.startTest();
            AuthUserServices.setLoginError(new List<Auth_User__c>{ authUserSource, authUserTarget });
        Test.stopTest();

        almJob = [SELECT Login_Error__c FROM ALM_Job__c WHERE Id=:almJob.Id];

        System.assertEquals(true, almJob.Login_Error__c, 'The login error checkbox should be set to true after any refresh token has been invalidated and updated.');
    }
}