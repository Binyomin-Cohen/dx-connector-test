public with sharing class PopulateModifiedUsersBatch implements Database.Batchable<sObject>, Database.Stateful {

    List<String> errors = new List<String>();
    Set<String> users = new Set<String>();

    public Database.Querylocator start(Database.BatchableContext bc) {
        String query = 'SELECT Id, Last_Modified_Users__c, Field_Modified_Data__c FROM Component__c';
        return Database.getQueryLocator(query);
    }

    public void execute(Database.BatchableContext BC, List<sObject> scope) {

        List<Component__c> modifiedComponents = (List<Component__c>) scope;
        Set<String> newUsers = ComponentServices.populateLastModifiedUsers(modifiedComponents);

        try {
            update modifiedComponents;
        } catch (Exception e) {
            errors.add(e.getMessage());
        }
        users.addAll(newUsers);
    }

    public void finish(Database.BatchableContext BC) {

        try {
            ALMSettingsServices.bulkInsertNewComponentUserSettings(users);
        } catch (Exception e) {
            errors.add(e.getMessage());
        }

        if (errors.size() > 0) {
            String errorMessage = String.join(errors, '\n');
            ALMLogServices.error(new ALMException(errorMessage), ALMLogServices.Application.PM_POST_INSTALL_SCRIPT);
        }
    }
}