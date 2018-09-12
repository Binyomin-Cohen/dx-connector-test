@isTest
private class TestCustomBacklogModel {
    public static testMethod void testGetCountAsString() {
        System.assertEquals('9', CustomBacklogModel.getCountAsString(9), 'Numbers below 1000 should be returned as is');
        System.assertEquals('242', CustomBacklogModel.getCountAsString(242), 'Numbers below 1000 should be returned as is');
        System.assertEquals('999+', CustomBacklogModel.getCountAsString(1000), 'Numbers above 999 should be returned as 999+');
    }
    public static testMethod void testUniversalCustomBacklogModel() {
        Custom_Backlog__c testCustomBacklog = TestingUtils.createCustomBacklog('U_test');
        Custom_Backlog__c testUniversalCustomBacklog = TestingUtils.buildCustomBacklog('U_test');
        testUniversalCustomBacklog.Universal__c = true;
        insert testUniversalCustomBacklog;

        Test.startTest();
            CustomBacklogModel actualUniversalModel = new CustomBacklogModel(testUniversalCustomBacklog);
            CustomBacklogModel actualNonUniversalModel = new CustomBacklogModel(testCustomBacklog);
        Test.stopTest();

        System.assertEquals(null, actualUniversalModel.totalItems, 'The total items should not be set');
        System.assertEquals(null, actualUniversalModel.unprioritizedItems, 'The unprioritized items should not be set');
        System.assertEquals(BacklogManagementHomeController.MASTER_BACKLOG_IDENTIFIER, actualUniversalModel.customBacklogId, 'The master identifier should be set as the id');

        System.assertEquals(testCustomBacklog.Id, actualNonUniversalModel.customBacklogId, 'The record id should be set as the id');
        System.assertEquals('0', actualNonUniversalModel.totalItems, 'The totalItems should be zero');
        System.assertEquals('0', actualNonUniversalModel.unprioritizedItems, 'The unprioritized should be zero');
    }
}