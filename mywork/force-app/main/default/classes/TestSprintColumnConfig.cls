@isTest
private class TestSprintColumnConfig {

    static List<String> backlogItemStatusValues;

    private static void setup() {
        backlogItemStatusValues = SObjectServices.getPicklistValues(Schema.SObjectType.Backlog__c.fields.Status__c);
    }

    static Integer STATIC_COLUMN_COUNT = 1;

    static testMethod void loadUnusedColumns_noActiveColumns() {
        setup();
        Test.startTest();

            SprintColumnConfig columnConfig = new SprintColumnConfig();

        Test.stopTest();

        Integer expectedUnusedColumnCount = backlogItemStatusValues.size();

        System.assertEquals(expectedUnusedColumnCount, columnConfig.unusedColumns.size(),
            'The number of unused columns should be the number of status picklist values without any static values');
        System.assertEquals(STATIC_COLUMN_COUNT, columnConfig.activeColumns.size(),
            'The number of active columns should be the number of static values');
        for (Integer i = 0; i < expectedUnusedColumnCount; ++i) {
            System.assertEquals(backlogItemStatusValues[i], columnConfig.unusedColumns[i].apiName,
                    'The status values should be listed in the same order as the picklist.');
        }
    }

    static testMethod void loadActiveColumns() {
        setup();

        ALM_Settings_List__c activeLane = ALMSettingsServices.buildSprintLaneSetting(backlogItemStatusValues[0], 1);

        insert activeLane;

        Test.startTest();

            SprintColumnConfig columnConfig = new SprintColumnConfig();

        Test.stopTest();

        Integer expectedActiveColumnCount = 1 + STATIC_COLUMN_COUNT;
        Integer expectedUnusedColumnCount = backlogItemStatusValues.size() - 1;

        System.assertEquals(expectedActiveColumnCount, columnConfig.activeColumns.size(),
            'The active columns should include any existing lanes and static columns');

        System.assertEquals(SprintModel.NOT_STARTED_STATUS, columnConfig.activeColumns[0].apiName,
            'The last lane should be the static column');

        System.assertEquals(activeLane.Value__c, columnConfig.activeColumns[1].apiName,
            'The selected Lane should be returned in order.');

        System.assertEquals(expectedUnusedColumnCount, columnConfig.unusedColumns.size(),
            'The number of unused columns should be the number of status picklist values without any static values');
    }
}