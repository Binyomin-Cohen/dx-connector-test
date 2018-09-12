@isTest
private class TestCustomBacklogViewExt {

    static testMethod void customBacklogViewRedirectsToCorrectPage_withPermissions() {
        ALMSettings__c settings = new ALMSettings__c(Enable_Custom_Backlogs__c = true);
        insert settings;

        Custom_Backlog__c customBacklog = new Custom_Backlog__c();
        insert customBacklog;

        ApexPages.StandardController sc = new ApexPages.StandardController( customBacklog );
        CustomBacklogViewExt customBacklogMgmtController = new CustomBacklogViewExt(sc);

        Test.startTest();
            PageReference redirect = customBacklogMgmtController.doRedirect();
        Test.stopTest();

        Map<String, String> redirectParams = redirect.getParameters();

        System.assertEquals(customBacklog.Id, redirectParams.get(BacklogManagementExt.CUSTOM_BACKLOG_ID_PARAM),
                            'The user should be redirected to the Backlog Items Management page');
    }

    static testMethod void customBacklogViewRedirectsToCorrectPage_withoutPermissions() {
        Custom_Backlog__c customBacklog = new Custom_Backlog__c();
        insert customBacklog;

        ApexPages.StandardController sc = new ApexPages.StandardController( customBacklog );
        CustomBacklogViewExt customBacklogMgmtController = new CustomBacklogViewExt(sc);

        Test.startTest();
            PageReference redirect = customBacklogMgmtController.doRedirect();
        Test.stopTest();

        Map<String, String> redirectParams = redirect.getParameters();

        System.assertEquals(null, redirectParams.get(BacklogManagementExt.CUSTOM_BACKLOG_ID_PARAM),
                            'No custom backlog id should be provided to the redirect');
    }
}
