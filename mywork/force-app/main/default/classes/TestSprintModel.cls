@isTest
private class TestSprintModel {

    static testMethod void sprintItemCompletedStatus_blank() {
        System.assertEquals('', SprintModel.ITEM_COMPLETED_STATUS, 'Completed status should be treated as blank when there is no configuration');
    }

    static testMethod void sprintItemCompletedStatus() {
        String completedStatus = 'Done';

        List<ALM_Settings_List__c> settings = new List<ALM_Settings_List__c> {
            ALMSettingsServices.buildSprintLaneSetting('A', 0),
            ALMSettingsServices.buildSprintLaneSetting('B', 1),
            ALMSettingsServices.buildSprintLaneSetting(completedStatus, 2)
        };

        insert settings;

        Test.startTest();
            System.assertEquals(completedStatus, SprintModel.ITEM_COMPLETED_STATUS, 'Completed status should be set to the last configured sprint item status.');
        Test.stopTest();
    }
}