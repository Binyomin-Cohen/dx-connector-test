@isTest
private with sharing class TestAuthUserTrigger {
    static testMethod void setAlmJobInvalidLogin_validSetToTrue() {
        Instances__c sourceInstance = new Instances__c(Name='Test Source Instance');
        insert sourceInstance;
        Instances__c targetInstance = new Instances__c(Name='Test Target Instance');
        insert targetInstance;

        Auth_User__c authUser = TestingUtils.buildAuthUser(UserInfo.getUserId(), sourceInstance.Id, true);
        authUser.Is_Refresh_Token_Valid__c = true;
        insert authUser;

        ALM_Job__c almJob = new ALM_Job__c(Source_Instance__c=sourceInstance.Id, Target_Instance__c=targetInstance.Id, Login_Error__c=false);
        insert almJob;

        Test.startTest();
            authUser.Is_Refresh_Token_Valid__c=false;
            update authUser;
        Test.stopTest();

        almJob = [SELECT Login_Error__c FROM ALM_Job__c WHERE Id=:almJob.Id];

        System.assertEquals(true, almJob.Login_Error__c, 'A login error should be triggered after the auth user\'s refresh token is invalidated.');
    }

    static testMethod void setAlmJobInvalidLogin_validSetToFalse() {
        Instances__c sourceInstance = new Instances__c(Name='Test Source Instance');
        insert sourceInstance;
        Instances__c targetInstance = new Instances__c(Name='Test Target Instance');
        insert targetInstance;

        Auth_User__c authUser = TestingUtils.buildAuthUser(UserInfo.getUserId(), sourceInstance.Id, true);
        authUser.Is_Refresh_Token_Valid__c = false;
        insert authUser;

        ALM_Job__c almJob = new ALM_Job__c(Source_Instance__c=sourceInstance.Id, Target_Instance__c=targetInstance.Id, Login_Error__c=true);
        insert almJob;

        Test.startTest();
            authUser.Is_Refresh_Token_Valid__c=true;
            update authUser;
        Test.stopTest();

        almJob = [SELECT Login_Error__c FROM ALM_Job__c WHERE Id=:almJob.Id];

        System.assertEquals(false, almJob.Login_Error__c, 'A login error should be triggered after the auth user\'s refresh token is invalidated.');
    }
}