public with sharing class BacklogItemServices {
    public static final Id UNIVERSAL_BACKLOG_ID = null;

    public static Boolean RUN_TRIGGER = true;
    // Turned off until FB-01504 is handled.
    public static Boolean RUN_TRIGGER_AUTO_PRIORITIZE = false;

    public static final String DEFECT_RECORD_TYPE_NAME = 'Defect';
    public static final String STORY_RECORD_TYPE_NAME = 'Story';

    public static final Set<String> DEFAULT_COLUMNS = new Set<String> { 'Name', SObjectServices.getFullyQualifiedName('Status__c') };
    public static final String INACTIVE_STATUS_SEPARATOR = ';~';
    private static final Integer INACTIVE_STATUS_FIELD_COUNT = 2;

    public static final String MIN_IDENTIFIER = 'min';
    public static final String MAX_IDENTIFIER = 'max';
    @TestVisible
    private static final String DEFAULT_BACKLOG_NAME = System.Label.Backlog_Default_Name;

    public static Set<String> getInactiveStatuses() {

        Set<String> inactiveStatuses = new Set<String>();
        ALMSettings__c settings = ALMSettings__c.getOrgDefaults();

        for( Integer i = 1; i <= INACTIVE_STATUS_FIELD_COUNT; i++) {
            String fieldName = SObjectServices.getFullyQualifiedName('Inactive_Backlog_Statuses_' + i + '__c');
            String statuses = (String) settings.get( fieldName );
            if (String.isNotBlank( statuses )) {
                inactiveStatuses.addAll( statuses.split(INACTIVE_STATUS_SEPARATOR) );
            }
        }
        return inactiveStatuses;
    }

    public static Backlog__c getBacklogRecord( Id backlogId ){
        List<Backlog__c> backlogItems = [SELECT Name FROM Backlog__c WHERE Id = :backlogId];
        if (backlogItems.isEmpty()) {
            ApexPages.addMessage(new ApexPages.Message(
               ApexPages.Severity.ERROR,
               System.Label.Generic_Error + ': Invalid Backlog Item Id.'
            ));
            return null;
        }
        return backlogItems[0];
    }

    /**
    * Gets all fields on Backlog__c excluding rich text fields.
    */
    public static List<Column> getFields() {
        Map<String, Schema.SObjectField> fieldInfo = Backlog__c.SObjectType.getDescribe().fields.getMap();

        List<Column> fields = new List<Column>();
        for (Schema.SObjectField field : fieldInfo.values()) {
            Schema.DescribeFieldResult fieldDesc = field.getDescribe();
            if (!fieldDesc.isHtmlFormatted()) {
                fields.add( new Column(fieldDesc) );
            }
        }
        return fields;
    }

    public static List<Column> getPrioritizationFields() {
        Map<String, Schema.SObjectField> fieldInfo = Backlog__c.SObjectType.getDescribe().fields.getMap();
        Map<String, Schema.DescribeFieldResult> namespaceFieldInfo = new Map<String, Schema.DescribeFieldResult>();
        for (Schema.SObjectField field : fieldInfo.values()) {
            Schema.DescribeFieldResult fieldDesc = field.getDescribe();
            namespaceFieldInfo.put(fieldDesc.getName(), fieldDesc);
        }

        List<Column> fields = new List<Column>();
        for(ALM_Settings_List__c field : ALMSettingsServices.getPrioritizationColumnSettings()) {
            if (namespaceFieldInfo.containsKey(field.Value__c)) {
                fields.add( new Column(namespaceFieldInfo.get(field.Value__c)) );
            }
        }

        return fields;
    }

    public static Integer getAllowableQueryRows() {
        return Limits.getLimitQueryRows() - Limits.getQueryRows();
    }

    public static Integer getCustomPrioritizedItemCount(Id backlogId, Set<Id> alreadyQueriedItems) {
        Integer totalPrioritizedItems = [
							            SELECT count()
							            FROM Backlog__c
							             WHERE Custom_Priority__c != null
							              AND Custom_Backlog__c =: backlogId
							              AND Status__c NOT IN :getInactiveStatuses()
							              AND ID NOT IN :alreadyQueriedItems
							              LIMIT :getAllowableQueryRows()
							            ];

        totalPrioritizedItems += alreadyQueriedItems.size();
        return totalPrioritizedItems;
    }

    public static Integer getPrioritizedItemCount(Set<Id> alreadyQueriedItems) {
        Integer totalPrioritizedItems = [
						                SELECT count()
						                FROM Backlog__c
						                 WHERE Priority__c != null
						                  AND Status__c NOT IN :getInactiveStatuses()
						                  AND ID NOT IN :alreadyQueriedItems
						                  LIMIT :getAllowableQueryRows()
						               ];
        totalPrioritizedItems += alreadyQueriedItems.size();

        return totalPrioritizedItems;
    }

    /*
    *  Updates backlog prioritization fields with passed in values. Any fields not present will be deleted!
    *  @throws ALMException
    */
    public static void savePrioritizationFields(List<String> newFields) {
        List<ALM_Settings_List__c> existingFields = ALMSettingsServices.getPrioritizationColumnSettings();

        List<ALM_Settings_List__c> newSettings = new List<ALM_Settings_List__c>();

        for(Integer i = 0; i < newFields.size(); i++) {
            newSettings.add(ALMSettingsServices.buildPrioritizationColumnSetting(newFields[i], i));
        }

        System.Savepoint sp = Database.setSavepoint();

        try {
            delete existingFields;
            insert newSettings;
        } catch (DMLException e) {
            Database.rollBack(sp);
            throw new ALMException('An error occured updating the inactive statuses: '+ e.getMessage());
        }
    }

    /*
    *  Updates inactive statuses with passed in values. Any statuses not present will be deleted!
    *  @throws DMLException
    */
    public static void saveInactiveStatuses(List<String> statuses) {
        ALMSettings__c settings = ALMSettings__c.getOrgDefaults();

        for (Integer i = 1; i <= INACTIVE_STATUS_FIELD_COUNT; i++) {
            String fieldName = SObjectServices.getFullyQualifiedName('Inactive_Backlog_Statuses_' + i + '__c');
            settings.put( fieldName, '' );
        }

        Integer currentFieldIndex = 1;
        while (currentFieldIndex <= INACTIVE_STATUS_FIELD_COUNT && !statuses.isEmpty()) {
            String status = statuses.remove(0);

            String fieldName = SObjectServices.getFullyQualifiedName('Inactive_Backlog_Statuses_' + currentFieldIndex + '__c');

            String currentValue = (String)settings.get( fieldName );
            String newValue = sObjectServices.appendValue(currentValue, status, INACTIVE_STATUS_SEPARATOR);
            if (status.length() > 0 && currentValue == newValue) {
                currentFieldIndex++;
                fieldName = SObjectServices.getFullyQualifiedName('Inactive_Backlog_Statuses_' + currentFieldIndex + '__c');
                settings.put(fieldName, status);
            } else {
                settings.put(fieldName, newValue);
            }
        }

        upsert settings;
    }

    public static List<UserAssignment> getUserAssignments(String backlogId) {
        return getUserAssignments(backlogId, '');
    }

    public static List<UserAssignment> getUserAssignments(String backlogId, String filter) {
        List<UserAssignment> users = new List<UserAssignment>();

        String query = 'SELECT Id, Backlog__c, ALM_User__c, ALM_User__r.Name, ALM_User__r.User__r.Name,';
        query += 'Role__c, Role__r.Name';

        if (ALMUserServices.isChatterEnabled()) {
            query += ', ALM_User__r.User__r.SmallPhotoUrl';
        }

        query += ' FROM ' + SObjectServices.getFullyQualifiedName('Backlog_User__c');
        query += ' WHERE Backlog__c = \'' + backlogId +'\'';
        if (!String.isEmpty(filter)) {
            query += ' AND ' + filter;
        }

        for (Backlog_User__c backlogUser : Database.query( query )) {
            users.add(new UserAssignment(backlogUser));
        }

        return users;
    }

    public static Map<Id, Id> getBacklogItemIdsWithLatestSprintIds(Set<Id> bklgIds){
        Map<Id, Id> backlogIdSprintIdMap = new Map<Id, Id>();
        for ( Backlog__c bklg : [Select Id, (Select Id, Sprint__c From Sprint_Items__r ORDER By Sprint__r.Start_Date__c DESC NULLS LAST LIMIT 1) From Backlog__c Where Id in :bklgIds])
        {
            backlogIdSprintIdMap.put(bklg.Id, !bklg.Sprint_Items__r.isEmpty() ? bklg.Sprint_Items__r[0].Sprint__c : null);
        }
        return backlogIdSprintIdMap;
    }

    public static List<Backlog__c> populateCurrentSprintOnBacklogs(Map<Id, Id> backlogIdToSprintIds){
        List<Backlog__c> bklgs = new List<Backlog__c>();
        Map<Id, Backlog__c> currentBklgs = new Map<Id, Backlog__c>([Select Id, Current_Sprint__c from Backlog__c Where Id in :backlogIdToSprintIds.keySet()]);
        for (Id backlogId : backlogIdToSprintIds.keySet()){
            if (currentBklgs.containsKey(backlogId) && currentBklgs.get(backlogId).Current_Sprint__c !=  backlogIdToSprintIds.get(backlogId)){
                bklgs.add(new Backlog__c(Id=backlogId, Current_Sprint__c = backlogIdToSprintIds.get(backlogId)));
            }
        }
        return bklgs;
    }

    /**
      * Calls database update on the input Backlog records and catches DMLExceptions.
      * @param bklgsToUpdate the specified records to update
      * @return a list of DMLException error messages with failed ID.
     */
    public static List<String> updateBacklogs(List<Backlog__c> bklgsToUpdate){
        List<String> errorMessages = new List<String>();
        try {
            update bklgsToUpdate;
        }
        catch (DMLException de){
            for (Integer i = 0; i < de.getNumDml(); i++) {
                Integer failedIndex = de.getDmlIndex(i);
                String failedMessage = de.getDmlMessage(i);
                bklgsToUpdate[failedIndex].addError( failedMessage );
                errorMessages.add(bklgsToUpdate[failedIndex].Id + ' : ' + failedMessage);
            }
            ALMLogServices.error(de, ALMLogServices.Application.BACKLOG_MANAGEMENT);
        }
        return errorMessages;
    }

    /**
    * Returns a filtered version of newBacklogItems containing only items that are in oldBacklogItems whose corresponding sprint values do not match.
    * @param oldBacklogItems One version of the backlog items.
    * @param newBacklogItems Another version of the same backlog items.
    * @return A filtered version of newBacklogItems.
    */
    public static List<Backlog__c> filterBacklogItemsWithModifiedSprints(Map<Id, Backlog__c> oldBacklogItems, List<Backlog__c> newBacklogItems) {
        if (oldBacklogItems == null) {
            return newBacklogItems;
        }

        List<Backlog__c> filteredBacklogItems = new List<Backlog__c>();
        for (Backlog__c newBacklogItem : newBacklogItems) {
            Backlog__c oldBacklogItem = oldBacklogItems.get(newBacklogItem.Id);

            if (oldBacklogItem != null) {
                Id oldSprintId = oldBacklogItem.Current_Sprint__c;
                Id newSprintId = newBacklogItem.Current_Sprint__c;

                if (oldSprintId != newSprintId) {
                    filteredBacklogItems.add(newBacklogItem);
                }
            } else {
                filteredBacklogItems.add(newBacklogItem);
            }
        }

        return filteredBacklogItems;
    }

    /**
    * Updates sprint items affected by a change in backlog item status.
    * @param newList - A list of the new versions of backlog items.
    * @param oldMap - A map of backlog IDs associated with old versions of their records.
    * @return Map<Id, List<String>> - A map associating backlog item IDs with a list of error messages.
    */
    public static Map<Id, List<String>> updateStatusOnSprintItems(List<Backlog__c> newList, Map<Id, Backlog__c> oldMap) {
        List<Backlog__c> backlogItemsWithChangedStatuses = SObjectServices.filterObjectsWithFieldUpdate(
            newList,
            oldMap,
            Schema.Backlog__c.Status__c
        );

        if (backlogItemsWithChangedStatuses.isEmpty()) {
            return new Map<Id, List<String>>();
        }

        Map<Id, Backlog__c> backlogItemIdToRecord = new Map<Id, Backlog__c>();
        for (Backlog__c backlogItem : backlogItemsWithChangedStatuses) {
            backlogItemIdToRecord.put(backlogItem.Id, backlogItem);
        }

        List<Sprint_Item__c> sprintItemsToUpdate = [
            SELECT Backlog__c, Status__c
            FROM Sprint_Item__c
            WHERE
                Backlog__c IN :backlogItemIdToRecord.keySet() AND
                Sprint__r.Status__c != :SprintModel.COMPLETED_STATUS
        ];

        Map<Id, Column> backlogIdToColumn =
            SprintServices.getFurthestCompletedSprintColumn(backlogItemsWithChangedStatuses);
        for (Sprint_Item__c sprintItem : sprintItemsToUpdate) {
            Column furthestCompletedSprintColumn = backlogIdToColumn.get(sprintItem.Backlog__c);
            sprintItem.Status__c =
                furthestCompletedSprintColumn == null ? SprintModel.NOT_STARTED_STATUS : furthestCompletedSprintColumn.label;
        }

        Map<Id, List<String>> errorMap = new Map<Id, List<String>>();
        try {
            update sprintItemsToUpdate;
        } catch (DMLException de) {
            for (Integer i = 0; i < de.getNumDml(); ++i) {
                Sprint_Item__c failedSprintItem = sprintItemsToUpdate[de.getDmlIndex(i)];
                if (failedSprintItem != null) {
                    Backlog__c associatedBacklogItem = backlogItemIdToRecord.get(failedSprintItem.Backlog__c);
                    if (associatedBacklogItem != null) {
                        String errorMessage = de.getDmlMessage(i);
                        associatedBacklogItem.addError(errorMessage);
                        if (errorMap.get(associatedBacklogItem.Id) == null) {
                            errorMap.put(associatedBacklogItem.Id, new List<String>());
                        }
                        errorMap.get(associatedBacklogItem.Id).add(errorMessage);
                    }
                }
            }
            ALMLogServices.error(de, ALMLogServices.Application.SPRINT);
        }

        return errorMap;
    }

    /**
    * Retrieves the auto-prioritization behavior for a backlog.
    * @param backlogId - The ID of the backlog for which auto-prioritization behavior will be retrieved.
    * @return - The auto-prioritization behavior of the backlog.
    */
    public static BacklogAutoPrioritizationModel.PrioritizationBehavior getBacklogAutoPrioritizationBehavior(Id backlogId) {
        BacklogAutoPrioritizationModel backlogAutoPrioritizationConfigurationModel = new BacklogAutoPrioritizationModel(backlogId);

        List<Backlog_Auto_Prioritization__c> backlogAutoPrioritizationConfigurations = [
            SELECT Prioritization_Behavior__c
            FROM Backlog_Auto_Prioritization__c
            WHERE Backlog_ID__c = :backlogId
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        if (!backlogAutoPrioritizationConfigurations.isEmpty()) {
            backlogAutoPrioritizationConfigurationModel.setBehavior(backlogAutoPrioritizationConfigurations[0].Prioritization_Behavior__c);
        }

        return backlogAutoPrioritizationConfigurationModel.behavior;
    }

    /**
    * Modifies the auto-prioritization behavior for a backlog.
    * @param backlogId - The ID of the backlog for which auto-prioritization behavior will be modified.
    * @param behavior - The desired auto-prioritization behavior of the backlog.
    */
    public static void setBacklogAutoPrioritizationBehavior(Id backlogId, BacklogAutoPrioritizationModel.PrioritizationBehavior behavior) {
        try {
            upsert new BacklogAutoPrioritizationModel(backlogId, behavior).getRecord() Name;
        } catch (DMLException e) {
            ALMLogServices.error(
                new ALMException(System.Label.Backlog_Auto_Prioritization_Custom_Setting_Upsert_Error),
                ALMLogServices.Application.BACKLOG_MANAGEMENT
            );
        }
    }

    /**
    * Auto-prioritizes the given backlog items based on existing org custom metadata type configurations.
    * @param backlogItems - A list of backlog items to prioritize, in descending order of priority.
    */
    public static void autoPrioritizeBacklogItems(List<Backlog__c> backlogItems) {
        autoPrioritizeBacklogItems(mapBacklogAutoPrioritizationModelToBacklogItems(backlogItems));
    }

    @TestVisible
    private static void autoPrioritizeBacklogItems(Map<BacklogAutoPrioritizationModel, List<Backlog__c>> backlogAutoPrioritizationModelToBacklogItems) {
        if (backlogAutoPrioritizationModelToBacklogItems == null || backlogAutoPrioritizationModelToBacklogItems.isEmpty()) {
            return;
        }

        // Collect the IDs of all relevant custom backlogs.
        Set<Id> backlogIds = new Set<Id>();
        for (BacklogAutoPrioritizationModel configuration : backlogAutoPrioritizationModelToBacklogItems.keySet()) {
            if (configuration != null) {
                backlogIds.add(configuration.backlogId);
            }
        }

        Map<Id, BacklogPriorityExtremesModel> backlogIdToPriorityExtremes = mapBacklogIdToPriorityExtremes(backlogIds);

        // Set the priorities (for both universal and custom backlogs) for all of the given backlog items.
        for (BacklogAutoPrioritizationModel configuration : backlogAutoPrioritizationModelToBacklogItems.keySet()) {
            if (configuration != null) {
                // Retrieve all of the given backlog items for the current backlog auto-prioritization configuration.
                List<Backlog__c> backlogItems = backlogAutoPrioritizationModelToBacklogItems.get(configuration);

                if (backlogItems != null && !backlogItems.isEmpty() && configuration.behavior != BacklogAutoPrioritizationModel.PrioritizationBehavior.OFF) {
                    // Determine whether the current configuration should be mutating the backlog items' universal or custom priorities.
                    Schema.SObjectField priorityField = configuration.backlogId == UNIVERSAL_BACKLOG_ID ? Backlog__c.Priority__c : Backlog__c.Custom_Priority__c;

                    if (configuration.behavior == BacklogAutoPrioritizationModel.PrioritizationBehavior.TOP) {
                        // If the prioritization behavior is "Top", prioritize all of the given backlog items for the current backlog at the top of the current backlog.
                        Integer minimumExistingPriority =
                            backlogIdToPriorityExtremes.containsKey(configuration.backlogId) ?
                            backlogIdToPriorityExtremes.get(configuration.backlogId).minimumPriority :
                            0;
                        for (Backlog__c backlogItem : backlogItems) {
                            // Prioritize all of the given backlog items for the current backlog by incrementing up toward the backlog's current minimal priority value.
                            backlogItem.put(priorityField, (-1 * backlogItems.size()) + (minimumExistingPriority++));
                        }
                    } else if (configuration.behavior == BacklogAutoPrioritizationModel.PrioritizationBehavior.BOTTOM) {
                        // If the prioritization behavior is "Bottom", prioritize all of the given backlog items for the current backlog at the bottom of the current backlog.
                        Integer maximumExistingPriority =
                            backlogIdToPriorityExtremes.containsKey(configuration.backlogId) ?
                            backlogIdToPriorityExtremes.get(configuration.backlogId).maximumPriority :
                            0;
                        for (Backlog__c backlogItem : backlogItems) {
                            // Prioritize all of the new backlog items for the current backlog by incrementing up from the backlog's current maximal priority value.
                            backlogItem.put(priorityField, ++maximumExistingPriority);
                        }
                    }
                }
            }
        }
    }

    private static Map<BacklogAutoPrioritizationModel, List<Backlog__c>> mapBacklogAutoPrioritizationModelToBacklogItems(List<Backlog__c> backlogItems) {
        if (backlogItems == null || backlogItems.isEmpty()) {
            return null;
        }

        // Group all of the given backlog items by backlog (both universal and custom backlogs).
        Map<Id, List<Backlog__c>> backlogIdToBacklogItems = new Map<Id, List<Backlog__c>>();
        for (Backlog__c backlogItem : backlogItems) {
            addElementToMappedList(backlogIdToBacklogItems, UNIVERSAL_BACKLOG_ID, backlogItem);

            if (backlogItem.Custom_Backlog__c != null) {
                addElementToMappedList(backlogIdToBacklogItems, backlogItem.Custom_Backlog__c, backlogItem);
            }
        }

        // Associate all of the relevant backlog auto-prioritization configurations with their given backlog items.
        Map<BacklogAutoPrioritizationModel, List<Backlog__c>> backlogAutoPrioritizationModelToBacklogItems = new Map<BacklogAutoPrioritizationModel, List<Backlog__c>>();
        for (Backlog_Auto_Prioritization__c backlogAutoPrioritizationConfiguration : [SELECT Backlog_ID__c, Prioritization_Behavior__c FROM Backlog_Auto_Prioritization__c WHERE Backlog_ID__c IN :backlogIdToBacklogItems.keySet()]) {
            backlogAutoPrioritizationModelToBacklogItems.put(
                new BacklogAutoPrioritizationModel(backlogAutoPrioritizationConfiguration),
                backlogIdToBacklogItems.get(backlogAutoPrioritizationConfiguration.Backlog_ID__c));
        }

        return backlogAutoPrioritizationModelToBacklogItems;
    }

    private static Map<Id, List<Backlog__c>> addElementToMappedList(Map<Id, List<Backlog__c>> mappedLists, Id key, Backlog__c value) {
        List<Backlog__c> currentElements = mappedLists.get(key);
        if (currentElements == null) {
            currentElements = new List<Backlog__c>();
        }

        currentElements.add(value);

        mappedLists.put(key, currentElements);

        return mappedLists;
    }

    private static Integer getPriorityExtremeFromUniversalBacklog(String extremeIdentifier) {
        Integer extremePriority = 0;
        String queryOrder = extremeIdentifier == MIN_IDENTIFIER ? 'ASC' : 'DESC';

        List<Backlog__c> universalBacklogPriorityRecord = Database.query(SObjectServices.getFullyQualifiedQuery('SELECT Id, Priority__c '
										                                                                        +'FROM Backlog__c '
										                                                                        +'WHERE Priority__c != null '
										                                                                        +'ORDER BY Priority__c '+queryOrder+ ' '
										                                                                        +'LIMIT 1'));
        if (!universalBacklogPriorityRecord.isEmpty()) {
            extremePriority = Integer.valueOf(universalBacklogPriorityRecord[0].Priority__c);
        }
        return extremePriority;
    }

    private static void setPriorityExtremeFromCustomBacklog(Map<Id, Map<String, Integer>> backlogIdToMinAndMaxValues, String extremeIdentifier ) {

        String queryOrder = extremeIdentifier == MIN_IDENTIFIER ? 'ASC' : 'DESC';

        for (Custom_Backlog__c custBacklog : Database.query( SObjectServices.getFullyQualifiedQuery('SELECT Id, '
									                                                                +'(SELECT Custom_Backlog__c, Custom_Priority__c '
									                                                                 +'FROM Backlog_Items__r '
									                                                                 +'WHERE Custom_Priority__c != null '
									                                                                 +'ORDER BY Custom_Priority__c '+queryOrder+ ' '
									                                                                 +'LIMIT 1) '
									                                                              +'FROM Custom_Backlog__c'))) {

           Map<String, Integer> universalMaxAndMin = new Map<String, Integer>{MIN_IDENTIFIER=>0,MAX_IDENTIFIER=>0};

           if (!custBacklog.Backlog_Items__r.isEmpty()) {
               if (backlogIdToMinAndMaxValues.containsKey(custBacklog.Id)) {
                   universalMaxAndMin = backlogIdToMinAndMaxValues.get(custBacklog.Id);
               }
               universalMaxAndMin.put(extremeIdentifier, Integer.valueOf(custBacklog.Backlog_Items__r[0].Custom_Priority__c));
           }
           backlogIdToMinAndMaxValues.put(custBacklog.Id, universalMaxAndMin);
        }
    }

    private static Map<Id, BacklogPriorityExtremesModel> mapBacklogIdToPriorityExtremes(Set<Id> backlogIds) {
        List<AggregateResult> results = new List<AggregateResult>();
        Map<Id, Map<String, Integer>> backlogIdToMinAndMaxValues = new Map<Id, Map<String, Integer>>();

        if (backlogIds.remove(UNIVERSAL_BACKLOG_ID)) {
            Map<String, Integer> universalMaxAndMin = new Map<String, Integer>{MIN_IDENTIFIER=>0,MAX_IDENTIFIER=>0};

            universalMaxAndMin.put(MIN_IDENTIFIER, getPriorityExtremeFromUniversalBacklog(MIN_IDENTIFIER));
            universalMaxAndMin.put(MAX_IDENTIFIER, getPriorityExtremeFromUniversalBacklog(MAX_IDENTIFIER));

            backlogIdToMinAndMaxValues.put(BacklogItemServices.UNIVERSAL_BACKLOG_ID, universalMaxAndMin);
        }

        setPriorityExtremeFromCustomBacklog(backlogIdToMinAndMaxValues, MIN_IDENTIFIER );
        setPriorityExtremeFromCustomBacklog(backlogIdToMinAndMaxValues, MAX_IDENTIFIER );

        Map<Id, BacklogPriorityExtremesModel> backlogIdToPriorityExtremes = new Map<Id, BacklogPriorityExtremesModel>();
        for (Id backlogId : backlogIdToMinAndMaxValues.keySet()) {
            try {
                Map<String,Integer> minAndMaxValues = backlogIdToMinAndMaxValues.get(backlogId);
                BacklogPriorityExtremesModel extremesModel = new BacklogPriorityExtremesModel(backlogId, minAndMaxValues);
                backlogIdToPriorityExtremes.put(backlogId, extremesModel);
            } catch (SObjectException soe) {
                ALMLogServices.error(soe, ALMLogServices.Application.BACKLOG_MANAGEMENT);
            } catch (TypeException te) {
                ALMLogServices.error(te, ALMLogServices.Application.BACKLOG_MANAGEMENT);
            }
        }

        return backlogIdToPriorityExtremes;
    }

    private class BacklogPriorityExtremesModel {
        public Id backlogId;
        public Integer minimumPriority;
        public Integer maximumPriority;
        private AggregateResult queryResult;

        public BacklogPriorityExtremesModel(Id backlogId, Map<String,Integer> minAndMaxValues) {
            this.backlogId = backlogId;
            this.minimumPriority = minAndMaxValues.get(BacklogItemServices.MIN_IDENTIFIER);
            this.maximumPriority = minAndMaxValues.get(BacklogItemServices.MAX_IDENTIFIER);
        }
    }
}