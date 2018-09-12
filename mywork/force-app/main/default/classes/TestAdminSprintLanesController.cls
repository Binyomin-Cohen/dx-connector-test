@isTest
private class TestAdminSprintLanesController {
    private static testmethod void saveColumns() {
        List<String> statuses = new List<String> {'Not Started', 'In Progress'};
        Test.startTest();

            AdminSprintLanesController.saveColumns(statuses);

        Test.stopTest();

        List<ALM_Settings_List__c> sprintLanes = ALMSettingsServices.getSprintLaneSettings();

        System.assertEquals(2, sprintLanes.size(), 'All selected sprint lanes should be saved.');
        System.assertEquals(statuses[0], sprintLanes[0].Value__c, 'Sprint lanes should be returned in order.');
        System.assertEquals(statuses[1], sprintLanes[1].Value__c, 'Sprint lanes should be returned in order.');
    }

    private static testmethod void saveColumns_removingColumns() {
        ALM_Settings_List__c col1 = ALMSettingsServices.buildSprintLaneSetting('col1', 1);
        ALM_Settings_List__c col2 = ALMSettingsServices.buildSprintLaneSetting('col2', 2);
        insert new List<ALM_Settings_List__c>{col1, col2};

        Test.startTest();

            AdminSprintLanesController.saveColumns(new List<String>{col1.Value__c});

        Test.stopTest();

        List<ALM_Settings_List__c> sprintLanes = ALMSettingsServices.getSprintLaneSettings();

        System.assertEquals(1, sprintLanes.size(), 'Only selected sprint lanes should be saved.');
        System.assertEquals(col1.Value__c, sprintLanes[0].Value__c, 'Sprint lanes should be returned in order.');
    }
}