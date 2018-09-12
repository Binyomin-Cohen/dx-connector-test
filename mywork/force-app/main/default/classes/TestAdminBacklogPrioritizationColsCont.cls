@isTest
private class TestAdminBacklogPrioritizationColsCont {

    static Integer STATIC_COLUMN_COUNT = 1;

    static testMethod void loadColumns_NoActive() {
        Test.startTest();

            AdminBacklogPrioritizationColsCont controller = new AdminBacklogPrioritizationColsCont();

        Test.stopTest();

        System.assert(!controller.columnConfig.unusedColumns.isEmpty(), 'Unused columns should not be empty');
        Integer defaultColumnCount = BacklogItemServices.DEFAULT_COLUMNS.size() + STATIC_COLUMN_COUNT;
        System.assertEquals(defaultColumnCount,  controller.columnConfig.activeColumns.size(), 'Active columns should contain all default columns');

        for (Column column : controller.columnConfig.unusedColumns) {
            System.assert(!BacklogPrioritizationColumnConfig.columnsToExclude.contains(column.apiName), 'Excluded columns should not be loaded.');
        }
        for (Column column : controller.columnConfig.activeColumns) {
            System.assertEquals(true, column.isDefault, 'Each default column should be marked as default.');
        }
    }

    static testMethod void loadColumns() {
        List<ALM_Settings_List__c> settings = new List<ALM_Settings_List__c>();
        ALM_Settings_List__c setting1 = ALMSettingsServices.buildPrioritizationColumnSetting('CreatedDate', 1);
        settings.add( setting1 );

        Integer order = 2;
        for ( String defaultColumn : BacklogItemServices.DEFAULT_COLUMNS) {
            ALM_Settings_List__c setting = ALMSettingsServices.buildPrioritizationColumnSetting(defaultColumn, order++);
            settings.add(setting);
        }

        System.runAs( TestingUtils.ADMIN_USER) {
            insert settings;
        }

        Test.startTest();

            AdminBacklogPrioritizationColsCont controller = new AdminBacklogPrioritizationColsCont();

        Test.stopTest();

        Integer defaultColumnCount = BacklogItemServices.DEFAULT_COLUMNS.size();

        System.assert(!controller.columnConfig.unusedColumns.isEmpty(), 'Unused columns should not be empty');
        System.assertEquals(settings.size(), controller.columnConfig.activeColumns.size() - STATIC_COLUMN_COUNT, 'Active columns should contain the created columns');
        System.assertEquals(setting1.Value__c, controller.columnConfig.activeColumns[1].apiName, 'Active columns should contain the created columns in order');
    }
}