public with sharing class SprintHomeController {

    public static final Integer MAX_COMPLETED_SPRINTS = 12;
    public static final Integer EXECUTABLE_QUERY_LIMIT = 5;
    public static final Integer INITIAL_BACKLOG_ROW_LIMIT = 100;
    public static final Integer BACKLOG_QUERY_LIMIT = 50;
    public Boolean hasPermissions {get; set;}
    public String sprintStatuses {get; set;}
    public Id backlogId {get; set;}
    public String backlogName {get; set;}
    public List<SelectOption> backlogs {get; set;}

    public SprintHomeController() {
        sprintStatuses = String.join(SprintServices.getStatuses(), ',');
        hasPermissions = PermissionServices.checkPagePermissions(new SprintPermissions()) == PermissionServices.PermissionLevel.FULL;

        User_Preferences__c userPreferences = User_Preferences__c.getValues(UserInfo.getUserId());
        if (userPreferences != null) {
            if (userPreferences.Sprint_Home_Default_Backlog_ID__c != null) {
                backlogId = userPreferences.Sprint_Home_Default_Backlog_ID__c;
            } else if (userPreferences.Default_Custom_Backlog_Id__c != null) {
                backlogId = userPreferences.Default_Custom_Backlog_Id__c;
            } else {
                backlogId = BacklogManagementHomeController.MASTER_BACKLOG_RECORD_ID;
            }
        } else {
            backlogId = BacklogManagementHomeController.MASTER_BACKLOG_RECORD_ID;
        }

        List<Custom_Backlog__c> matchingBacklogs = [SELECT Name FROM Custom_Backlog__c WHERE Id = :backlogId];
        if (!matchingBacklogs.isEmpty()) {
            backlogName = matchingBacklogs[0].Name;
        }

        backlogs = new List<SelectOption>();
        List<Custom_Backlog__c> customBacklogs = [SELECT Id, Name, Universal__c FROM Custom_Backlog__c ORDER BY Name ASC];
        for (Custom_Backlog__c customBacklog : customBacklogs) {
            backlogs.add(new SelectOption(customBacklog.Id, customBacklog.Name));
        }
    }

    @RemoteAction
    public static String createSprint(String name) {
        Sprint__c sprint = new Sprint__c(Name = name, Status__c = SprintModel.NOT_STARTED_STATUS);
        insert sprint;
        return sprint.Id;
    }

    /**
    * @throws ALMException, DMLException
    * @param sprintId - The ID of the sprint for which to create a new sprint item.
    * @param backlogId - The ID of the backlog item from which to create a new sprint item.
    * @return ID of the new sprint item on successful creation, otherwise throws an exception.
    */
    @RemoteAction
    public static String createSprintItem(String sprintId, String backlogId) {
        return SprintItemServices.createSprintItem(sprintId, backlogId);
    }

    @RemoteAction
    public static void deleteSprint(String id) {
        Sprint__c sprint = new Sprint__c(Id = id);
        delete sprint;
    }

    public static Integer getBacklogItemsCount(List<String> alreadyQueriedIds) {
        return getBacklogItemsCount(null, alreadyQueriedIds);
    }

    /**
    * Returns a total number of unassigned backlog items plus the number of sprint items that are incomplete
    */
    @RemoteAction
    public static Integer getBacklogItemsCount(Id backlogId, List<String> alreadyQueriedIds) {
        Set<String> inactiveStatuses = BacklogItemServices.getInactiveStatuses();

        if (alreadyQueriedIds == null) {
            alreadyQueriedIds = new List<String>();
        }

        String queryString = 
            'SELECT COUNT() ' +
            'FROM Backlog__c ' +
            'WHERE Id NOT IN ( SELECT Backlog__c ' +
                            'FROM Sprint_Item__c  ' +
                            'WHERE Status__c != \'' + SprintModel.INCOMPLETE_STATUS + '\') ';

        if (!inactiveStatuses.isEmpty()) {
            queryString += 'AND Status__c NOT IN ' + BluewolfDevUtils.flattenListForQuery(new List<String>(inactiveStatuses)) + ' ';
        }

        if (!alreadyQueriedIds.isEmpty()) {
            queryString += 'AND Id NOT IN ' + BluewolfDevUtils.flattenListForQuery(new List<String>(alreadyQueriedIds)) + ' ';
        }

        if (!String.isEmpty(backlogId) && backlogId != BacklogManagementHomeController.MASTER_BACKLOG_RECORD_ID) {
            queryString += 'AND Custom_Backlog__c = \'' + backlogId + '\' ';
        }

        queryString += 'LIMIT ' + LimitServices.getRemainingQueryRowsAvailable();

        return Database.countQuery(queryString) + alreadyQueriedIds.size();
    }

    public static List<BacklogItemModel> getAssignableBacklogItems(List<String> excludeIds) {
        return getAssignableBacklogItems(null, excludeIds);
    }

    /**
    * Returns a filtered list of backlog items, excluding a list of Ids and limiting the result count
    * @param excludeIds - List of Ids to exclude from the database query
    */
    @RemoteAction
    public static List<BacklogItemModel> getAssignableBacklogItems(Id backlogId, List<String> excludeIds) {
        List<BacklogItemModel> backlogItems = new List<BacklogItemModel>();

        for (Backlog__c backlogRecord : SprintServices.getFilteredBacklogItems(backlogId, BACKLOG_QUERY_LIMIT, excludeIds)) {
            backlogItems.add( new BacklogItemModel(backlogRecord) );
        }

        return backlogItems;
    }

    public static List<BacklogItemModel> getInitialBacklogItems() {
        return getInitialBacklogItems(null);
    }

    /**
    * Returns an initial list of assignable backlog items when loading the Sprint Home page
    */
    @RemoteAction
    public static List<BacklogItemModel> getInitialBacklogItems(Id backlogId) {
        List<BacklogItemModel> assignableBacklogItems = new List<BacklogItemModel>();
        Set<String> inactiveStatuses = BacklogItemServices.getInactiveStatuses();
        inactiveStatuses.add(SprintModel.INCOMPLETE_STATUS);

        Integer queryLimit = EXECUTABLE_QUERY_LIMIT;
        Integer queryOffset = 0;

        do {
            String queryString = 
                'SELECT Name, RecordType.Name, Status__c, Summary__c, Dev_Effort__c, Business_Value__c, ' +
                'Priority__c, User_Goal__c, ' +
                    '(SELECT Id FROM Sprint_Items__r WHERE Status__c != \'' + SprintModel.INCOMPLETE_STATUS + '\')' +
                'FROM  Backlog__c ';

            if (!inactiveStatuses.isEmpty()) {
                queryString += 'WHERE Status__c NOT IN ' + BluewolfDevUtils.flattenListForQuery(new List<String>(inactiveStatuses)) + ' ';
            }

            if (!String.isEmpty(backlogId) && backlogId != BacklogManagementHomeController.MASTER_BACKLOG_RECORD_ID) {
                queryString += 'AND Custom_Backlog__c = \'' + backlogId + '\' ';
            }

            queryString += 
                'ORDER BY Priority__c ASC NULLS LAST ' +
                'LIMIT ' + INITIAL_BACKLOG_ROW_LIMIT + ' ' +
                'OFFSET ' + queryOffset;
            List<Backlog__c> backlogItems = Database.query(queryString);
            if (!backlogItems.isEmpty()) {
                for( Backlog__c backlogItem : backlogItems) {
                    if( backlogItem.Sprint_Items__r.isEmpty() ) {
                        assignableBacklogItems.add( new BacklogItemModel(backlogItem) );
                        if (assignableBacklogItems.size() >= BACKLOG_QUERY_LIMIT) {
                            queryLimit = 0;
                            break;
                        }
                    }
                }
                queryOffset += INITIAL_BACKLOG_ROW_LIMIT;
                queryLimit--;
            } else {
                queryLimit = 0;
            }
        } while (queryLimit > 0);


        return assignableBacklogItems;
    }

    @RemoteAction
    public static AllSprintsResponse getAllSprints() {

        List<Sprint__c> activeSprints = [
            SELECT Id, Start_Date__c, End_Date__c, Name, Status__c
            FROM Sprint__c
            WHERE Status__c != :SprintModel.COMPLETED_STATUS
            ORDER BY Start_Date__c ASC NULLS FIRST, CreatedDate DESC
            LIMIT 500
        ];

        List<Sprint__c> completedSprints = [
            SELECT Id, Start_Date__c, End_Date__c, Name, Status__c
            FROM Sprint__c
            WHERE Status__c = :SprintModel.COMPLETED_STATUS
            ORDER BY Start_Date__c DESC NULLS LAST
            LIMIT :MAX_COMPLETED_SPRINTS
        ];

        List<SprintModel> activeSprintData = SprintServices.getSprintData( activeSprints );
        List<SprintModel> completedSprintData = SprintServices.getSprintData( completedSprints );

        return new AllSprintsResponse( activeSprintData, completedSprintData );
    }

    @RemoteAction
    public static SprintModel reassignIncompleteItems(String sourceSprintId, String targetSprintId) {
        List<Sprint_Item__c> itemsForReassignment =
            SprintServices.getSprintItemsForReassignment(sourceSprintId);

        List<Sprint_Item__c> newSprintItems = new List<Sprint_Item__c>();

        for(Sprint_Item__c item : itemsForReassignment) {
            Sprint_Item__c newSprintItem = new Sprint_Item__c( Sprint__c = targetSprintId, Backlog__c = item.Backlog__c);
            newSprintItem.Status__c = SprintModel.NOT_STARTED_STATUS;
            newSprintItems.add( newSprintItem );
            item.Status__c = SprintModel.INCOMPLETE_STATUS;
        }

        insert newSprintItems;
        update itemsForReassignment;
        SprintModel updatedSprint = SprintServices.getSprintData([
            SELECT Id, Start_Date__c, End_Date__c, Name, Status__c
            FROM Sprint__c
            WHERE Id = :targetSprintId
         ])[0];
        return updatedSprint;
    }

    @RemoteAction
    public static List<BacklogItemModel> sendIncompleteItemsToBacklog(String sprintId) {
        Set<Id> backlogItemIds = new Set<Id>();
        List<Sprint_Item__c> itemsForReassignment =
            SprintServices.getSprintItemsForReassignment(sprintId);

        for(Sprint_Item__c item : itemsForReassignment) {
            item.Status__c = SprintModel.INCOMPLETE_STATUS;
            backlogItemIds.add( item.Backlog__c );
        }

        update itemsForReassignment;

        return SprintServices.getBacklogItems( backlogItemIds );
    }

    @RemoteAction
    public static void updateSprintName(String sprintId, String name) {
        Sprint__c sprint = new Sprint__c(Id = sprintId, Name = name);
        update sprint;
    }

    @RemoteAction
    public static void updateDefaultBacklog(Id backlogId) {
        User_Preferences__c userPreferences = User_Preferences__c.getValues(UserInfo.getUserId());
        if (userPreferences != null) {
            userPreferences.Sprint_Home_Default_Backlog_ID__c = backlogId;
        } else {
            userPreferences = new User_Preferences__c(
                SetupOwnerId = UserInfo.getUserId(),
                Sprint_Home_Default_Backlog_ID__c = backlogId
            );
        }

        try {
            upsert userPreferences;
        } catch (Exception e) {
            throw new ALMException(e.getMessage());
        }
    }

    public class AllSprintsResponse {
        public List<SprintModel> completedSprints;
        public List<SprintModel> activeSprints;

        public AllSprintsResponse(List<SprintModel> activeSprints, List<SprintModel> completedSprints) {
            this.activeSprints = activeSprints;
            this.completedSprints = completedSprints;
        }
    }

}