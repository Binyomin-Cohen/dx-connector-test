public with sharing class ALMSettingsServices {
    public static final String AVAILABLE_COMPONENT_USERS_SETTING_TYPE = 'ComponentUsers';
    public static final String PRIORITIZATION_COLUMN_SETTING_TYPE = 'BacklogPrioritizationColumn';
    public static final String SPRINT_LANE_SETTING_TYPE = 'SprintLane';

    public static List<ALM_Settings_List__c> getSettingsList(String type) {
        return [
            SELECT Value__c, Order__c
            FROM   ALM_Settings_List__c
            WHERE  Type__c = :type
            ORDER BY Order__c, Value__c
        ];
    }

    public static List<ALM_Settings_List__c> getAvailableComponentUsersSettings() {
        return getSettingsList(AVAILABLE_COMPONENT_USERS_SETTING_TYPE);
    }

    public static List<ALM_Settings_List__c> getPrioritizationColumnSettings() {
        return getSettingsList(PRIORITIZATION_COLUMN_SETTING_TYPE);
    }

    public static List<ALM_Settings_List__c> getSprintLaneSettings() {
        return getSettingsList(SPRINT_LANE_SETTING_TYPE);
    }

    public static ALM_Settings_List__c buildAvailableComponentUsersSetting(String value, Integer order) {
        return buildListSetting(value, AVAILABLE_COMPONENT_USERS_SETTING_TYPE, order);
    }

    public static ALM_Settings_List__c buildPrioritizationColumnSetting(String value, Integer order) {
        return buildListSetting(value, PRIORITIZATION_COLUMN_SETTING_TYPE, order);
    }

    public static ALM_Settings_List__c buildSprintLaneSetting(String value, Integer order) {
        return buildListSetting(value, SPRINT_LANE_SETTING_TYPE, order);
    }

    public static ALM_Settings_List__c buildListSetting(String value, String type, Integer order) {
        return new ALM_Settings_List__c(
            Type__c = type,
            Value__c = value,
            Order__c = order,
            Name = type + order
        );
    }

    public static void bulkInsertNewComponentUserSettings(Set<String> users) {
        List<ALM_Settings_List__c> existingUserSettings = getAvailableComponentUsersSettings();
        Integer nextOrder = existingUserSettings.isEmpty() ? 0 :
                Integer.valueOf(existingUserSettings[existingUserSettings.size() - 1].Order__c) + 1;

        // Build a set of usernames from the custom settings
        Set<String> existingUsernames = Pluck.strings(ALM_Settings_List__c.Value__c, existingUserSettings);

        Set<String> newUsers = users.clone();
        newUsers.removeAll(existingUsernames);

        List<ALM_Settings_List__c> newUserSettings = new List<ALM_Settings_List__c>();
        for (String user : newUsers) {
            newUserSettings.add(buildAvailableComponentUsersSetting(user, nextOrder));
            nextOrder++;
        }
        insert newUserSettings;
    }
}