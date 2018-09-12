global class BwAlmPmPostInstall implements InstallHandler {

    global void onInstall(InstallContext context) {
        PopulateUnsupportedMetadataCustomSetting script = new PopulateUnsupportedMetadataCustomSetting();
        PopulateAlmPrivateCustomSetting almPrivateCustomSetting = new PopulateAlmPrivateCustomSetting();

        if (context.previousVersion() == null) {
            script.populateCustomSetting();
            almPrivateCustomSetting.populateCustomSetting();
            SnapshotInstallServices.createAlmJobSnapshotAndMappings();
            CustomBacklogServices.createUniversalBacklogIfMissing();
            PopulateALMSettings.populateCustomSettingEnableMultipleBacklogs();

        } else if (context.previousVersion().compareTo(new Version(2,0)) < 0) {
            UpdateExistingBacklogComponentRecords batchUpdate = new UpdateExistingBacklogComponentRecords();
            ID batchProcessId = Database.executeBatch(batchUpdate);
        } else if (context.previousVersion().compareTo(new Version(2,3)) < 0) {
            UpdateExistingComponents batchUpdate2 = new UpdateExistingComponents();
            ID batchProcess2Id =  Database.executeBatch(batchUpdate2);
        }

        if (context.previousVersion() != null && context.previousVersion().compareTo(new Version(2,21)) < 0) {
            UpdateExistingComponentKeys compKeyBatch = new UpdateExistingComponentKeys();
            ID compKeyBatchProcessId = Database.executeBatch(compKeyBatch);
        }

        if (context.isUpgrade() || context.isPush()) {
            List<UnsupportedMetadataTypes__c> records = UnsupportedMetadataTypes__c.getAll().values();
            if (records.size() == 0) {
                script.populateCustomSetting();
            }

            if (!almPrivateCustomSetting.isCustomSettingPopulated()) {
                almPrivateCustomSetting.populateCustomSetting();
                PopulateAlmPrivateCustomSetting.clearAuthTokens();
            }
        }

        if (context.previousVersion() != null && context.previousVersion().compareTo(new Version(2, 23)) <= 0) {
            PopulateModifiedUsersBatch populateModifiedUsersBatch = new PopulateModifiedUsersBatch();
            Database.executeBatch(populateModifiedUsersBatch);
        }

        if (context.previousVersion() != null &&
            context.previousVersion().compareTo(new Version(2,23)) <= 0) {
            UpdateExistingBacklogItems batchUpdate3 = new UpdateExistingBacklogItems();
            ID batchProcess3Id =  Database.executeBatch(batchUpdate3);
        }

        if (context.previousVersion() != null &&
            context.previousVersion().compareTo(new Version(3,2,0)) < 0) {
            SnapshotInstallServices.createAlmJobSnapshotAndMappings();
        }

        if (context.previousVersion() != null &&
            context.previousVersion().compareTo(new Version(3,5,0)) < 0) {
            CustomBacklogServices.createUniversalBacklogIfMissing();
            PopulateALMSettings.populateCustomSettingEnableMultipleBacklogs();
        }
    }
}