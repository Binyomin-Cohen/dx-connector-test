@isTest
private class TestBwAlmPmPostInstall {

    static testMethod void testInstallScript_Fresh_Install() {
        BwAlmPmPostInstall postInstall = new BwAlmPmPostInstall();
        Test.testInstall(postInstall, null);
        List<UnsupportedMetadataTypes__c> records = UnsupportedMetadataTypes__c.getAll().values();
        System.assertEquals(PopulateUnsupportedMetadataCustomSetting.unsupportedTypesList.size(), records.size(), 'Expected number of Unsupported Metadata Types is not correct');
    }

    static testMethod void testInstallScript_Upgrade_No_Prior_CustomSetting() {
        BwAlmPmPostInstall postInstall = new BwAlmPmPostInstall();
        Test.testInstall(postInstall, new Version(10,0));
        List<UnsupportedMetadataTypes__c> records = UnsupportedMetadataTypes__c.getAll().values();
        System.assertEquals(PopulateUnsupportedMetadataCustomSetting.unsupportedTypesList.size(), records.size(), 'Expected number of Unsupported Metadata Types is not correct');
    }

    static testMethod void testInstallScript_Upgrade_Has_Exising_CustomSetting() {
        // Assert cutom setting is empty
        List<UnsupportedMetadataTypes__c> records = UnsupportedMetadataTypes__c.getAll().values();
        System.assertEquals(0, records.size(), 'Custom Setting should be empty');

        // Create a record
        UnsupportedMetadataTypes__c rec = new UnsupportedMetadataTypes__c();
        rec.Name = 'Foo';
        rec.Name__c = 'Foo';
        insert rec;

        records = UnsupportedMetadataTypes__c.getAll().values();
        System.assertEquals(1, records.size(), 'Custom Setting should have 1 record');

        // Upgrade
        BwAlmPmPostInstall postInstallUpgrade = new BwAlmPmPostInstall();
        Test.testInstall(postInstallUpgrade, new Version(10,0));
        List<UnsupportedMetadataTypes__c> actual = UnsupportedMetadataTypes__c.getAll().values();
        System.assertEquals(1, actual.size(), 'Expected number of Unsupported Metadata Types is not correct');

        // Push Upgrade
        BwAlmPmPostInstall postInstallPush = new BwAlmPmPostInstall();
        Test.testInstall(postInstallPush, new Version(10,0), true);
        List<UnsupportedMetadataTypes__c> pushActual = UnsupportedMetadataTypes__c.getAll().values();
        System.assertEquals(1, pushActual.size(), 'Expected number of Unsupported Metadata Types is not correct');
    }

    static testMethod void onInstall_executePopulateModifiedUsersBatch() {
        String USERNAME = 'Target User';
        String USERNAME2 = 'Target User2';

        Instances__c instance = TestingUtils.createInstance('dev');
        Component__c component = TestingUtils.buildComponent('Test trigger', 'Trigger', instance.Id);

        FieldModifiedData lastModifiedData0 = new FieldModifiedData(instance.Name, null, USERNAME, null, 'somebody');
        FieldModifiedData lastModifiedData1 = new FieldModifiedData(instance.Name, null, USERNAME2, null, 'somebody');

        component.Field_Modified_Data__c = JSON.serialize(new List<FieldModifiedData>{
                lastModifiedData0, lastModifiedData1});

        insert component;

        Test.startTest();
            // Upgrade
            BwAlmPmPostInstall postInstallUpgrade = new BwAlmPmPostInstall();
            Test.testInstall(postInstallUpgrade, new Version(2, 23));
        Test.stopTest();

        Component__c updatedComponent = [
                SELECT Id, Last_Modified_Users__c
                FROM Component__c
                WHERE Id = :component.Id
        ];

        Set<String> lastModifiedUsers = new Set<String>(updatedComponent.Last_Modified_Users__c.split(';'));
        System.assertEquals(2, lastModifiedUsers.size(),
                'Last_Modified_Users__c should be populated with all users from the field modified data');
        System.assert(lastModifiedUsers.contains(USERNAME),
                'Last_Modified_Users__c should be populated with all users from the field modified data');
        System.assert(lastModifiedUsers.contains(USERNAME2),
                'Last_Modified_Users__c should be populated with all users from the field modified data');

        List<ALM_Settings_List__c> returnedSettings = ALMSettingsServices.getAvailableComponentUsersSettings();

        System.assertEquals(2, returnedSettings.size(), 'New users settings should be created');

        System.assertEquals(true, lastModifiedUsers.contains(returnedSettings[0].Value__c),
                'New users settings should be created');
        System.assertEquals(true, lastModifiedUsers.contains(returnedSettings[1].Value__c),
                'New users settings should be created');
    }

    static testMethod void almPrivateCustomSetting_Fresh_Install() {
        ALM_Private__c cs = ALM_Private__c.getOrgDefaults();
        System.assertEquals(null, cs.Callback_URL__c, 'Callback url should be empty');
        System.assertEquals(null, cs.Consumer_Key__c, 'Consumer key should be empty');
        System.assertEquals(null, cs.Consumer_Secret__c, 'Consumer secret should be empty');

        Test.startTest();
            BwAlmPmPostInstall postInstall = new BwAlmPmPostInstall();
            Test.testInstall(postInstall, null);
        Test.stopTest();

        ALM_Private__c actual = ALM_Private__c.getOrgDefaults();
        System.assertEquals(PopulateAlmPrivateCustomSetting.CALLBACK_URL, actual.Callback_URL__c, 'Callback url should not be empty');
        System.assertEquals(PopulateAlmPrivateCustomSetting.CONSUMER_KEY, actual.Consumer_Key__c, 'Consumer key should not be empty');
        System.assertEquals(PopulateAlmPrivateCustomSetting.CONSUMER_SECRET, actual.Consumer_Secret__c, 'Consumer secret should not be empty');
    }

    static testMethod void almPrivateCustomSetting_Upgrade_No_Prior_Value() {
        ALM_Private__c cs = ALM_Private__c.getOrgDefaults();
        System.assertEquals(null, cs.Callback_URL__c, 'Callback url should be empty');
        System.assertEquals(null, cs.Consumer_Key__c, 'Consumer key should be empty');
        System.assertEquals(null, cs.Consumer_Secret__c, 'Consumer secret should be empty');

        Test.startTest();
            BwAlmPmPostInstall postInstall = new BwAlmPmPostInstall();
            Test.testInstall(postInstall, new Version(10,0));
        Test.stopTest();

        ALM_Private__c actual = ALM_Private__c.getOrgDefaults();
        System.assertEquals(PopulateAlmPrivateCustomSetting.CALLBACK_URL, actual.Callback_URL__c, 'Callback url should not be empty');
        System.assertEquals(PopulateAlmPrivateCustomSetting.CONSUMER_KEY, actual.Consumer_Key__c, 'Consumer key should not be empty');
        System.assertEquals(PopulateAlmPrivateCustomSetting.CONSUMER_SECRET, actual.Consumer_Secret__c, 'Consumer secret should not be empty');
    }

    static testMethod void testUpdateExistingBacklogItems_CurrentSprintIsSetCorrectly() {

        Backlog__c backlog = new Backlog__c(Status__c = 'Open');
        Sprint__c firstSprint = new Sprint__c(Name = 'firstSprint', Status__c = SprintModel.COMPLETED_STATUS);

        insert firstSprint;
        insert backlog;

        Sprint_Item__c firstSprintItem = new Sprint_Item__c(Backlog__c = backlog.Id, Sprint__c = firstSprint.Id);
        insert firstSprintItem;

        backlog.Current_Sprint__c = Null;
        update backlog;

        Test.startTest();
            BwAlmPmPostInstall postInstall = new BwAlmPmPostInstall();
            Test.testInstall(postInstall, new Version(2,18));
        Test.stopTest();

        backlog = [Select Id, Current_Sprint__c from Backlog__c];
        System.assertEquals(firstSprint.Id, backlog.Current_Sprint__c, 'The current sprint for the backlog item should have been updated');
    }

    static testMethod void testUpdateExistingBacklogItems_Upgrade() {

        SprintItemServices.RUN_TRIGGER = false;
        UnitTest.addData(TestingUtils.buildSprints('test_sprint', 1)).tag('Sprints').insertAll();
        UnitTest.addData(TestingUtils.buildBacklogItems(1)).tag('Backlogs').insertAll();
        UnitTest.addData(TestingUtils.buildSprintItems(null, (List<Backlog__c>) UnitTest.get('Backlogs').getList() )).tag('Sprint Items');
        UnitTest.get('Sprint Items').property(SObjectServices.getFullyQualifiedName('Sprint__c')).assign(UnitTest.get('Sprints').getList()[0].Id);

        Map<Id, Backlog__c> bklgMap = new Map<Id, Backlog__c>([Select Current_Sprint__c from Backlog__c Where Id in :UnitTest.getIds('Backlogs')]);
        System.assertEquals(UnitTest.getIds('Backlogs') , bklgMap.keySet(), 'We expect to get back the correct number of backlogs.');

        for (Sprint_Item__c sItem : (List<Sprint_Item__c>)UnitTest.get('Sprint Items').getList()){
            System.assertEquals(null, bklgMap.get(sItem.Backlog__c).Current_Sprint__c, 'We expect the Backlog to be the same current sprint.');
        }

        UnitTest.get('Sprint Items').insertAll();

        Test.startTest();
            BwAlmPmPostInstall postInstall = new BwAlmPmPostInstall();
            Test.testInstall(postInstall, new Version(2,18));
        Test.stopTest();

        bklgMap = new Map<Id, Backlog__c>([Select Current_Sprint__c from Backlog__c Where Id in :UnitTest.getIds('Backlogs')]);
        System.assertEquals(UnitTest.getIds('Backlogs') , bklgMap.keySet(), 'We expect to get back the correct number of backlogs.');
        for (Sprint_Item__c sItem : (List<Sprint_Item__c>)UnitTest.get('Sprint Items').getList()){
            System.assertEquals(sItem.Sprint__c, bklgMap.get(sItem.Backlog__c).Current_Sprint__c, 'We expect the Backlog to be the same current sprint.');
        }

    }

    static testMethod void almPrivateCustomSetting_upgrade_hasPriorValue() {
        ALM_Private__c privateSetting = ALM_Private__c.getOrgDefaults();
        privateSetting.Callback_URL__c = 'some-value';
        privateSetting.Consumer_Key__c = 'some-value';
        privateSetting.Consumer_Secret__c = 'some-value';
        insert privateSetting;

        Auth_User__c existingAuthUser = new Auth_User__c(Access_Token__c='some-value',
            Refresh_Token__c = 'some-other-value', Is_Refresh_Token_Valid__c = true);
        insert existingAuthUser;

        Test.startTest();

            BwAlmPmPostInstall postInstallUpgrade = new BwAlmPmPostInstall();

            try {
                Test.testInstall(postInstallUpgrade, new Version(10,0));
            } catch (DMLException e) {
                System.assert(false, 'A duplicate entry should not be created in the custom setting.');
            }
        Test.stopTest();

        privateSetting = ALM_Private__c.getOrgDefaults();

        System.assertEquals(PopulateAlmPrivateCustomSetting.CALLBACK_URL, privateSetting.Callback_URL__c,
            'The callback url should be updated');
        System.assertEquals(PopulateAlmPrivateCustomSetting.CONSUMER_KEY, privateSetting.Consumer_Key__c,
            'The consumer key should be updated');
        System.assertEquals(PopulateAlmPrivateCustomSetting.CONSUMER_SECRET, privateSetting.Consumer_Secret__c,
            'The consumer secret should be updated');

        Auth_User__c updatedAuthUser = [SELECT Id, Refresh_Token__c, Access_Token__c
             FROM Auth_User__c WHERE Id = :existingAuthUser.Id];
        System.assertEquals(true, String.isBlank(updatedAuthUser.Refresh_Token__c), 'The existing refresh token should be cleared');
        System.assertEquals(true, String.isBlank(updatedAuthUser.Access_Token__c), 'The access token should be cleared');
    }

    static testMethod void almPrivateCustomSetting_pushUpgrade_hasPriorValue() {
        ALM_Private__c cs = ALM_Private__c.getOrgDefaults();
        System.assertEquals(null, cs.Callback_URL__c, 'Callback url should be empty');
        System.assertEquals(null, cs.Consumer_Key__c, 'Consumer key should be empty');
        System.assertEquals(null, cs.Consumer_Secret__c, 'Consumer secret should be empty');

        PopulateAlmPrivateCustomSetting almPrivateCustomSetting = new PopulateAlmPrivateCustomSetting();
        almPrivateCustomSetting.populateCustomSetting();

        cs = ALM_Private__c.getOrgDefaults();
        System.assertEquals(PopulateAlmPrivateCustomSetting.CALLBACK_URL, cs.Callback_URL__c, 'Callback url should not be empty');
        System.assertEquals(PopulateAlmPrivateCustomSetting.CONSUMER_KEY, cs.Consumer_Key__c, 'Consumer key should not be empty');
        System.assertEquals(PopulateAlmPrivateCustomSetting.CONSUMER_SECRET, cs.Consumer_Secret__c, 'Consumer secret should not be empty');

        Test.startTest();
            BwAlmPmPostInstall postInstallPush = new BwAlmPmPostInstall();

            try {
                Test.testInstall(postInstallPush, new Version(10,0), true);
            } catch (DMLException e) {
                System.assert(false, 'A duplicate entry should not be created in the custom setting.');
            }

        Test.stopTest();
    }

    static testMethod void testUpdateExistingBacklogItemsKey_Upgrade() {
        ComponentServices.RUN_TRIGGER = false;
        Component__c c1 = TestingUtils.buildComponentWithParent('Foo', 'Object', '');
        Component__c c2 = TestingUtils.buildComponentWithParent('Bar', 'Object', '');
        insert new List<Component__c> {c1, c2};

        Integer startCount = [Select count() from Component__c Where Key__c = ''];
        System.assertEquals(2, startCount, 'Expected 2 records with an empty Key__c value');

        ComponentServices.RUN_TRIGGER = true;

        Test.startTest();
            BwAlmPmPostInstall postInstall = new BwAlmPmPostInstall();
            Test.testInstall(postInstall, new Version(2,18));
        Test.stopTest();

        Integer endCount = [Select count() from Component__c Where Key__c = ''];
        System.assertEquals(0, endCount, 'All records should have a Key__c field set value');
    }

    static testMethod void testCreateSnapshotRecords_Install() {

        Test.startTest();
            BwAlmPmPostInstall postInstall = new BwAlmPmPostInstall();
            Test.testInstall(postInstall, null);
        Test.stopTest();

        List<ALM_Job__c> snapshots = [
            SELECT
                Id, Target_Object_Api_Name__c, Tool__c, Report_Developer_Name__c, Errors__c,
                (SELECT Id, ALM_Job__c, Report_Column__c, Target_Field_Api_Name__c FROM Snapshot_Field_Mappings__r)
            FROM ALM_Job__c
        ];

        System.assertEquals(1, snapshots.size(), 'One snapshot record should have been created');
        ALM_Job__c snapshotCreated = snapshots[0];
        System.assertEquals(ALMJobServices.getToolName(ALMJobServices.ToolType.SNAPSHOT), snapshotCreated.Tool__c,'The tool should be correctly set');
        System.assertEquals(SnapshotInstallServices.SNAPSHOT_REPORT_DEVELOPER_NAME, snapshotCreated.Report_Developer_Name__c,'The report should be correctly set');
        System.assertEquals(SnapshotInstallServices.SNAPSHOT_TARGET_OBJECT_NAME, snapshotCreated.Target_Object_Api_Name__c,'The target should be correctly set');
        System.assertEquals(SnapshotInstallServices.COLUMN_NAME_TO_FIELD_NAME.size(), snapshotCreated.Snapshot_Field_Mappings__r.size(),'The correct number of field mappings should be created');
    }

    static testMethod void testCreateSnapshotRecords_Upgrade_records_not_created() {

        Test.startTest();
            BwAlmPmPostInstall postInstall = new BwAlmPmPostInstall();
            Test.testInstall(postInstall, new Version(4,0));
        Test.stopTest();

        List<ALM_Job__c> snapshots = [
            SELECT
                Id, Target_Object_Api_Name__c, Tool__c, Report_Developer_Name__c, Errors__c,
                (SELECT Id, ALM_Job__c, Report_Column__c, Target_Field_Api_Name__c FROM Snapshot_Field_Mappings__r)
            FROM ALM_Job__c
        ];

        System.assertEquals(0, snapshots.size(), 'No snapshot records should have been created');
    }

    static testMethod void testCreateSnapshotRecords_Upgrade_records_created() {

        Test.startTest();
            BwAlmPmPostInstall postInstall = new BwAlmPmPostInstall();
            Test.testInstall(postInstall, new Version(3,1,8));
        Test.stopTest();

        List<ALM_Job__c> snapshots = [
            SELECT
                Id, Target_Object_Api_Name__c, Tool__c, Report_Developer_Name__c, Errors__c,
                (SELECT Id, ALM_Job__c, Report_Column__c, Target_Field_Api_Name__c FROM Snapshot_Field_Mappings__r)
            FROM ALM_Job__c
        ];

        System.assertEquals(1, snapshots.size(), 'One snapshot record should have been created');
        ALM_Job__c snapshotCreated = snapshots[0];
        System.assertEquals(ALMJobServices.getToolName(ALMJobServices.ToolType.SNAPSHOT), snapshotCreated.Tool__c,'The tool should be correctly set');
        System.assertEquals(SnapshotInstallServices.SNAPSHOT_REPORT_DEVELOPER_NAME, snapshotCreated.Report_Developer_Name__c,'The report should be correctly set');
        System.assertEquals(SnapshotInstallServices.SNAPSHOT_TARGET_OBJECT_NAME, snapshotCreated.Target_Object_Api_Name__c,'The target should be correctly set');
        System.assertEquals(SnapshotInstallServices.COLUMN_NAME_TO_FIELD_NAME.size(), snapshotCreated.Snapshot_Field_Mappings__r.size(),'The correct number of field mappings should be created');
    }

    static testMethod void testCreateUniversalBacklogRecord_on_install() {

        Test.startTest();
            BwAlmPmPostInstall postInstall = new BwAlmPmPostInstall();
            Test.testInstall(postInstall, null);
        Test.stopTest();
        try{
            Custom_Backlog__c universalBacklog = CustomBacklogServices.MASTER_BACKLOG_RECORD;
        } catch (ALMException aex ) {
            System.assert(false, 'The universal backlog should exist.');
        }
    }

    static testMethod void testCreateUniversalBacklogRecord_on_upgrade() {

        Test.startTest();
            BwAlmPmPostInstall postInstall = new BwAlmPmPostInstall();
            Test.testInstall(postInstall, new Version(3,4,1));
        Test.stopTest();

        try{
            Custom_Backlog__c universalBacklog = CustomBacklogServices.MASTER_BACKLOG_RECORD;
        } catch (ALMException aex ) {
            System.assert(false, 'The universal backlog should exist.');
        }
    }

    static testMethod void testAvoidCreatingUniversalBacklogRecord_on_upgrade() {

        Test.startTest();
            BwAlmPmPostInstall postInstall = new BwAlmPmPostInstall();
            Test.testInstall(postInstall, new Version(3,5,1));
        Test.stopTest();

        try{
            Custom_Backlog__c universalBacklog = CustomBacklogServices.MASTER_BACKLOG_RECORD;
            System.assert(false, 'The universal backlog should not have been created.');
        } catch (ALMException aex ) {
            System.assertEquals(CustomBacklogServices.MISSING_UNIVERSAL_BACKLOG_MESSAGE, aex.getMessage(), 'The correct exception message should be shown');
        }
    }

    static testMethod void testEnableMultipleBacklogSettings_on_install() {

        Test.startTest();
            BwAlmPmPostInstall postInstall = new BwAlmPmPostInstall();
            Test.testInstall(postInstall, null);
        Test.stopTest();

        ALMSettings__c actualSetting = ALMSettings__c.getOrgDefaults();
        System.assertNotEquals(null, actualSetting, 'A settings record should be returned');
        System.assert(actualSetting.Enable_Custom_Backlogs__c, 'Multiple backlogs should be enabled');
    }

    static testMethod void testEnableMultipleBacklogSettings_on_upgrade() {

        Test.startTest();
            BwAlmPmPostInstall postInstall = new BwAlmPmPostInstall();
            Test.testInstall(postInstall, new Version(3,4,1));
        Test.stopTest();

        ALMSettings__c actualSetting = ALMSettings__c.getOrgDefaults();
        System.assertNotEquals(null, actualSetting, 'A settings record should be returned');
        System.assert(actualSetting.Enable_Custom_Backlogs__c, 'Multiple backlogs should be enabled');
    }

    static testMethod void testAvoidEnableMultipleBacklogSettings_on_upgrade() {

        Test.startTest();
            BwAlmPmPostInstall postInstall = new BwAlmPmPostInstall();
            Test.testInstall(postInstall, new Version(3,5,1));
        Test.stopTest();

        ALMSettings__c actualSetting = ALMSettings__c.getOrgDefaults();
        System.assertNotEquals(null, actualSetting, 'A settings record should be returned');
        System.assert(!actualSetting.Enable_Custom_Backlogs__c, 'Multiple backlogs should not be enabled');
    }
}