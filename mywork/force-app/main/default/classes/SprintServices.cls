public with sharing class SprintServices {

    public static final String DATE_FORMAT = 'MMM d' + String.escapeSingleQuotes(',') + ' yyyy';

    public static List<SprintModel> getSprintData( List<Sprint__c> sprints) {

        List<SprintModel> orderedSprints = new List<SprintModel>();

        Map<Id, SprintModel> sprintMap = new Map<Id, SprintModel>();

        for(Sprint__c sprint : sprints) {
            sprintMap.put( sprint.Id, new SprintModel( sprint ));
        }

        List<Sprint_Item__c> sprintTotals = [
            SELECT Sprint__c, Status__c, Backlog__r.Dev_Effort__c
            FROM Sprint_Item__c
            WHERE Sprint__c IN :sprintMap.keySet()
        ];

        for(Sprint_Item__c sprintItem : sprintTotals) {
            SprintModel sprint = sprintMap.get( sprintItem.Sprint__c );
            if (sprintItem.Backlog__r.Dev_Effort__c == null) {
                sprint.unestimatedItems++;
            } else {
                sprint.totalEffort += sprintItem.Backlog__r.Dev_Effort__c;
            }
            sprint.totalItems++;

            if (sprintItem.Status__c != SprintModel.ITEM_COMPLETED_STATUS) {
                sprint.incompleteItems++;
            }
            if (sprintItem.Status__c != SprintModel.ITEM_COMPLETED_STATUS
              && sprintItem.Status__c != SprintModel.INCOMPLETE_STATUS ) {
                sprint.itemsForReassignment++;
            }
        }

        for(Sprint__c sprint : sprints) {
            SprintModel sprintModel = sprintMap.get( sprint.Id );
            sprintModel.setHasItemsForReassignment();
            orderedSprints.add( sprintModel );
        }

        return orderedSprints;
    }

    public static List<Backlog__c> getFilteredBacklogItems(Integer limitBy, List<String> excludeIds) {
        return getFilteredBacklogItems(null, limitBy, excludeIds);
    }

    /**
    * Returns limited number of Backlog__c records that are not contained in the excludeIds list
    */
    public static List<Backlog__c> getFilteredBacklogItems(Id backlogId, Integer limitBy, List<String> excludeIds) {
        List<Backlog__c> backlogItems = new List<Backlog__c>();
        Set<String> inactiveStatuses = BacklogItemServices.getInactiveStatuses();
        inactiveStatuses.add('Incomplete');

        Integer remainingRows = LimitServices.getRemainingQueryRowsAvailable();
        if (limitBy > remainingRows) {
            limitBy = remainingRows;
        }

        String queryString =
            'SELECT Name, RecordType.Name, Status__c, Summary__c, Dev_Effort__c, Business_Value__c, ' +
             'Priority__c, User_Goal__c ' +
            'FROM  Backlog__c ' +
            'WHERE Id NOT IN ( SELECT Backlog__c ' +
                            'FROM Sprint_Item__c ' +
                            'WHERE Status__c != \'' + SprintModel.INCOMPLETE_STATUS + '\') ';

        if (!inactiveStatuses.isEmpty()) {
            queryString += 'AND Status__c NOT IN ' + BluewolfDevUtils.flattenListForQuery(new List<String>(inactiveStatuses)) + ' ';
        }

        if (!excludeIds.isEmpty()) {
            queryString += 'AND Id NOT IN ' + BluewolfDevUtils.flattenListForQuery(excludeIds) + ' ';
        }

        if (!String.isBlank(backlogId) && backlogId != BacklogManagementHomeController.MASTER_BACKLOG_RECORD_ID) {
            queryString += ' AND Custom_Backlog__c = \'' + backlogId + '\' ';
        }

        queryString +=                  
            'ORDER BY Priority__c ASC NULLS LAST ' + 
            'LIMIT ' + limitBy;

        for( Backlog__c backlogItem : Database.query(queryString)) {
            backlogItems.add( backlogItem );
        }

        return backlogItems;
    }

    public static List<BacklogItemModel> getBacklogItems(Set<Id> backlogItemIds) {
        List<BacklogItemModel> backlogItems = new List<BacklogItemModel>();
        for (Backlog__c backlogRecord : [
            SELECT Name, RecordType.Name, Status__c, Summary__c, Dev_Effort__c,
              Business_Value__c, Priority__c, User_Goal__c
             FROM  Backlog__c
             WHERE Id IN :backlogItemIds
             ORDER BY Priority__c ASC NULLS LAST
        ]) {
            backlogItems.add( new BacklogItemModel(backlogRecord) );
        }
        return backlogItems;
    }

    public static List<Sprint_Item__c> getSprintItems(String sprintId) {
        return [
            SELECT Sprint__c, Backlog__c, Status__c,
             Backlog__r.Id, Backlog__r.Dev_Effort__c, Backlog__r.Business_Value__c, Backlog__r.User_Goal__c,
            Backlog__r.Name, Backlog__r.Summary__c, Backlog__r.Status__c, Backlog__r.RecordType.Name,
            Backlog__r.Priority__c
            FROM Sprint_Item__c
            WHERE Sprint__c = :sprintId
            ORDER By Backlog__r.Priority__c ASC
        ];
    }

    public static List<Sprint_Item__c> getSprintItemsForReassignment(String sprintId) {
        return [
            SELECT Id, Status__c, Backlog__c
             FROM Sprint_Item__c
             WHERE Sprint__c = :sprintId
             AND Status__c != :SprintModel.ITEM_COMPLETED_STATUS
             AND Status__c != :SprintModel.INCOMPLETE_STATUS
        ];
    }

    public static String getSprintDateFormat(String stringDate) {
      if (String.isEmpty(stringDate)) {
        return '';
      }

      Date d = Date.valueOf(stringDate);
      return getSprintDateFormat(d);
    }

    public static String getSprintDateFormat(Date d) {
      if (d == null) {
        return '';
      }

      Datetime dt = Datetime.newInstance(d.year(), d.month(), d.day());
      return dt.format(DATE_FORMAT);
    }

    public static List<String> getStatuses() {
        return SObjectServices.getPicklistValues( Schema.sObjectType.Sprint__c.fields.Status__c );
    }

    public static List<Column> getLanes() {
        Map<String, String> statusValueToLabel = SObjectServices.getPicklistValueMap(Schema.SObjectType.Backlog__c.fields.Status__c);
        List<Column> lanes = new List<Column>();
        for (ALM_Settings_List__c setting : ALMSettingsServices.getSprintLaneSettings()) {
            if (statusValueToLabel.containsKey(setting.Value__c)){
                lanes.add(new Column(setting.Value__c, statusValueToLabel.get(setting.Value__c)));
            } else {
                lanes.add(new Column(setting.Value__c));
            }
        }
        return lanes;
    }

    /**
     * Deletes any existing lane settings before inserting new ones.
     * @throws ALMException
     */
    public static void saveSprintLanes(List<String> newStatuses) {
        List<ALM_Settings_List__c> existingLanes = ALMSettingsServices.getSprintLaneSettings();
        List<ALM_Settings_List__c> newLanes = new List<ALM_Settings_List__c>();

        for (Integer i = 0; i < newStatuses.size(); ++i) {
            newLanes.add(ALMSettingsServices.buildSprintLaneSetting(newStatuses[i], i));
        }

        System.Savepoint sp = Database.setSavepoint();

        try {
            delete existingLanes;
            insert newLanes;
        } catch (DMLException e) {
            Database.rollBack(sp);
            throw new ALMException('An error occured updating the sprint lanes: '+ e.getMessage());
        }
    }

    public static Column getFurthestCompletedSprintColumn(Backlog__c backlogItem) {
        if (backlogItem == null) {
            return null;
        }

        Map<Id, Column> backlogIdToColumn = getFurthestCompletedSprintColumn(new Set<Backlog__c>{ backlogItem });

        return (backlogIdToColumn == null ? null : backlogIdToColumn.get(backlogItem.Id));
    }

    public static Map<Id, Column> getFurthestCompletedSprintColumn(List<Backlog__c> backlogItems) {
        return getFurthestCompletedSprintColumn(new Set<Backlog__c>(backlogItems));
    }

    public static Map<Id, Column> getFurthestCompletedSprintColumn(Set<Backlog__c> backlogItems) {
        // Retrieves all active sprint lanes.
        Set<String> sprintLaneStatuses = new Set<String>();
        for (Column sprintLaneColumn : getLanes()) {
            sprintLaneStatuses.add(sprintLaneColumn.apiName);
        }

        // This list provides a canonical ordering for backlog item statuses.
        List<String> backlogItemStatuses = SObjectServices.getPicklistValues(Schema.SObjectType.Backlog__c.fields.Status__c);

        // Determine the appropriate sprint column status for each backlog item.
        Map<Id, Column> backlogIdToColumn = new Map<Id, Column>();
        for (Backlog__c backlogItem : backlogItems) {
            if (sprintLaneStatuses.contains(backlogItem.Status__c)) {
                // The backlog item matches exactly to an active sprint column.
                backlogIdToColumn.put(backlogItem.Id, new Column(backlogItem.Status__c));
            } else {
                // Determine the index of the backlog item's status within the stage list, and decrement it to determine where to begin the search for the final status.
                Integer latestStageIndex = -1;
                for (Integer i = 0; i < backlogItemStatuses.size(); ++i) {
                    if (backlogItemStatuses[i].equals(backlogItem.Status__c)) {
                        latestStageIndex = i  - 1;
                        break;
                    }
                }

                // Do not attempt to match backlog statuses to sprint columns until later stages have been eliminated.
                for (Integer i = latestStageIndex; i >= 0; --i) {
                    // A proximity match has been found.
                    if (sprintLaneStatuses.contains(backlogItemStatuses[i])) {
                        backlogIdToColumn.put(backlogItem.Id, new Column(backlogItemStatuses[i]));
                        break;
                    }
                }
            }
        }

        return backlogIdToColumn;
    }

    public static Map<String, String> getStatusMap() {
        return SObjectServices.getPicklistValueMap(Schema.SObjectType.Sprint__c.fields.Status__c);
    }

    public static String getStatusPicklistLabel(String picklistValue) {
        Map<String, String> valuesToLabelMap = getStatusMap();

        if (valuesToLabelMap.containsKey(picklistValue)) {
            return valuesToLabelMap.get(picklistValue);
        } else {
            return picklistValue;
        }
    }
}