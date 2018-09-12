public with sharing class SprintDetailControllerExt {
    private ApexPages.StandardController sc;
    private List<Sprint_User__c> sprintUsersToDelete;
    private List<Sprint_Item__c> sprintItems;
    public Map<String, List<UserAssignment>> usersBySprintItem { get; set; }
    public String almUserIdToAdd {get; set;}

    public String sprintStatusValueMap {get; set;}
    
    public Integer totalDevEffort {
        get {
            if (totalDevEffort == null) {
                totalDevEffort = calculateDevEffort();
            }

            return totalDevEffort;
        }

        set;
    }

    public Integer totalBusinessValue {
        get {
            if (totalBusinessValue == null) {
                totalBusinessValue = calculateBuisnessValue();
            }

            return totalBusinessValue;
        }

        set;
    }

    public Boolean hasErrors {
        get {
            return ApexPages.hasMessages();
        }
    }

    public Boolean hasPermissions {get; set;}
    public String sprintStatuses { get; set; }

    public String sprintStartDate { get; set; }
    public String sprintEndDate { get; set; }

    public String releaseId { get; set; }
    public String releaseName { get; set; }
    public List<SprintLane> sprintLanes {get; set;}
    public Boolean showPlaceholder {
        get {
            return sprintLanes.size() == 1;
        }
    }

    public String selectedAlmUserId { get; set; }
    public List<UserAssignment> sprintUsers { get; set; }
    public SprintModel model {get; set;}

    @RemoteAction
    public static List<Release__c> getReleases(String term) {
        String searchString = (term == null) ? '%' : '%' + String.escapeSingleQuotes(term.trim()) + '%';
        return [SELECT Id, Name FROM Release__c WHERE Name LIKE :searchString ORDER BY Name ASC];
    }

    @RemoteAction
    public static void updateSprintItemStatus(String sprintItemId, String status) {

        List<Sprint_Item__c> items = [
            SELECT Id
            FROM  Sprint_Item__c
            WHERE Id = :sprintItemId
        ];

        if (items.size() == 0) {
            throw new ALMException('Sprint item not found.');
        }

        Sprint_Item__c sprintItem = new Sprint_Item__c(Id = sprintItemId);
        sprintItem.Status__c = status;

        System.savepoint sp = Database.setSavepoint();

        try {
            update sprintItem;
        } catch(DMLException de) {
            Database.rollback(sp);
            throw new ALMException('An error occurred updating this Backlog Item: '+ de.getMessage());
        }
    }

    @RemoteAction
    public static void deleteSprintItem(String id) {
        SprintItemServices.deleteSprintItem(id);
    }

    @RemoteAction
    public static List<UserAssignment> deleteSprintItemUser(String sprintId, String bklgUserId, String sprintItemId) {
        delete new Backlog_User__c(Id = bklgUserId);
        List<Sprint_Item__c> sprintItemsForUserDelete = [SELECT Id, Backlog__c FROM Sprint_Item__c WHERE Id = :sprintItemId];
        List<UserAssignment> users = getUsersBySprintItem(sprintId, sprintItemsForUserDelete).get(sprintItemId);
        return (users == null) ? new List<UserAssignment>() : users;
    }

    @RemoteAction
    public static List<ALM_User__c> searchALMUsers(String searchTarget) {
        return ALMUserServices.searchALMUsers(searchTarget);
    }

    @RemoteAction
    public static List<ALM_User_Role__c> searchUserRoles(String searchTarget) {
        return ALMUserServices.searchUserRoles(searchTarget);
    }

    @RemoteAction
    public static List<ALM_User__c> getALMUsers() {
        return ALMUserServices.getAllUsers();
    }

    @RemoteAction
    public static List<ALM_User_Role__c> getUserRoles() {
        return ALMUserServices.getAllRoles();
    }

    @RemoteAction
    public static Id assignUser(String sprintItemId, String userId, String role) {
        List<Sprint_Item__c> items = [SELECT Backlog__r.Id
                                       FROM  Sprint_Item__c
                                       WHERE Id = :sprintItemId];

        if (items.size() == 0) {
            throw new ALMException('Sprint item not found.');
        }

        String backlogItemId = items[0].Backlog__r.Id;

        List<Backlog_User__c> existingUser = [SELECT Id
                                               FROM  Backlog_User__c
                                               WHERE Backlog__c = :backlogItemId
                                               AND   ALM_User__c = :userId];

        if (!existingUser.isEmpty()) {
            throw new ALMException('This user is already assigned to this item.');
        }

        Backlog_User__c bklgUser = new Backlog_User__c(
            Backlog__c = backlogItemId,
            ALM_User__c = userId,
            Role__c = role
        );

        try {
            insert bklgUser;
        } catch (DMLException e) {
            throw new ALMException('Failed to add user.');
        }
        return bklgUser.Id;
    }

    public SprintDetailControllerExt(ApexPages.StandardController sc) {
        this.sc = sc;
        hasPermissions = PermissionServices.checkPagePermissions(new SprintPermissions()) == PermissionServices.PermissionLevel.FULL;
        sprintUsersToDelete = new List<Sprint_User__c>();
        sprintStatusValueMap = JSON.serialize(SprintServices.getStatusMap());

        List<Sprint__c> sprint = [SELECT Id, Name, Status__c, Start_Date__c, End_Date__c, Release__c, Release__r.Name
                                   FROM  Sprint__c
                                   WHERE Id = :sc.getId()];

        sprintStartDate = String.valueOf(sprint[0].Start_Date__c);
        sprintEndDate = String.valueOf(sprint[0].End_Date__c);

        model = new SprintModel(sprint[0]);

        releaseId = sprint[0].Release__c;
        releaseName = sprint[0].Release__r.Name;

        sprintItems = SprintServices.getSprintItems( model.sprintId );
        initSprintStatuses();

        sprintUsers = getExistingSprintUsers();

        usersBySprintItem = getUsersBySprintItem(sc.getId(), sprintItems);
        initSprintLanes();
    }

    private static Map<String, List<UserAssignment>> getUsersBySprintItem(String sprintId, List<Sprint_Item__c> sprintItemsToFilter) {
        Map<Id, Id> sprintItemsByBacklogItem = getSprintItemIdByBacklogItemId(sprintItemsToFilter);
        Map<String, List<UserAssignment>> usersBySprintItem = new Map<String, List<UserAssignment>>();
        String query = 'SELECT Id, Backlog__c, ALM_User__c, ALM_User__r.Name, ALM_User__r.User__r.Name, Role__c,'
                     + 'Role__r.Name';

        if (ALMUserServices.isChatterEnabled()) {
            query += ', ALM_User__r.User__r.SmallPhotoUrl';
        }

        Set<Id> backlogItemIds = sprintItemsByBacklogItem.keySet();
        query += ' FROM ' + SObjectServices.getFullyQualifiedName('Backlog_User__c')
              + ' WHERE ALM_User__c IN (SELECT ALM_User__c FROM '
              + SObjectServices.getFullyQualifiedName('Sprint_User__c') + ' WHERE Sprint__c = \'' + String.escapeSingleQuotes(sprintId) + '\')'
              + ' AND Backlog__c IN :backlogItemIds';

        List<Backlog_User__c> allUsers = Database.query(query);


        for (Backlog_User__c user : allUsers) {
            String sprintItemId = ''+sprintItemsByBacklogItem.get(user.Backlog__c);
            if (!usersBySprintItem.containsKey(sprintItemId)) {
                usersBySprintItem.put(sprintItemId, new List<UserAssignment>());
            }
            if (usersBySprintItem.get(sprintItemId).size() < 3) {
                usersBySprintItem.get(sprintItemId).add(new UserAssignment(user));
            }
        }

        return usersBySprintItem;
    }

    private static Map<Id, Id> getSprintItemIdByBacklogItemId(List<Sprint_Item__c> sprintItems) {
        Map<Id, Id> result = new Map<Id, Id>();
        for (Sprint_Item__c item : sprintItems) {
            result.put(item.Backlog__c, item.Id);
        }
        return result;
    }

    public Integer calculateDevEffort() {
        Integer total = 0;
        for (SprintLane lane : sprintLanes) {
            total += (Integer) lane.totalEffort;
        }

        return total;
    }

    public Integer calculateBuisnessValue() {
        Integer total = 0;
        for (Sprint_Item__c item : sprintItems) {
            if (item.Backlog__r.Business_Value__c != null) {
                total += (Integer) item.Backlog__r.Business_Value__c;
            }
        }

        return total;
    }

    public void updateSprint() {
        Sprint__c currentSprint = new Sprint__c();
        currentSprint.Id = model.sprintId;
        currentSprint.Status__c = model.status;

        if (!String.isEmpty(sprintStartDate)) {
            currentSprint.Start_Date__c = Date.valueOf(sprintStartDate);
        }

        if (!String.isEmpty(sprintEndDate)) {
            currentSprint.End_Date__c = Date.valueOf(sprintEndDate);
        }

        if (String.isEmpty(releaseId)) {
            currentSprint.Release__c = null;
        } else {
            currentSprint.Release__c = releaseId;
        }

        try {
            update currentSprint;
            model = new SprintModel(currentSprint);
        } catch (DMLException e) {
            System.debug(e);
            String errorMsg = '';
            if (e.getDmlType(0) == System.StatusCode.FIELD_CUSTOM_VALIDATION_EXCEPTION) {
                errorMsg = System.Label.Validation_Message + ' ' + e.getDmlMessage(0);
            } else {
                errorMsg = System.Label.Generic_Error + ' \n'+ e.getMessage();
            }
            ApexPages.addMessage(new Apexpages.Message(ApexPages.Severity.ERROR, errorMsg));

            sprintStartDate = String.valueOf(model.startDate);
            sprintEndDate = String.valueOf(model.endDate);
        }
    }

    private void initSprintStatuses() {
        List<String> values = SprintServices.getStatuses();
        sprintStatuses = String.join(values, ',');
    }

    public void updateBacklogs() {
        List<Backlog__c> updateList = new List<Backlog__c>();

        for (Sprint_Item__c si : sprintItems) {
            updateList.add(new Backlog__c(Id=si.Backlog__c, Release__c=releaseId));
        }

        try {
            update updateList;
        } catch (DMLException e) {
            System.debug(e);
            ApexPages.addMessage( new Apexpages.Message(ApexPages.Severity.ERROR,
                                                        System.Label.Generic_Error + ' \n'+ e.getMessage() ));
            return;
        }
    }

    private void initSprintLanes() {
        sprintLanes = new List<SprintLane>();
        Map<String, SprintLane> itemMap = new Map<String, SprintLane>();

        sprintLanes.add( new SprintLane( SprintModel.NOT_STARTED_STATUS, SprintModel.NOT_STARTED_STATUS));
        for (Column column : SprintServices.getLanes()) {
            sprintLanes.add( new SprintLane( column.apiName, column.label ));
        }

        for( SprintLane sprintLane : sprintLanes) {
            itemMap.put( sprintLane.status, sprintLane );
        }

        for (Sprint_Item__c rawSprintItem : sprintItems) {
            List<UserAssignment> sprintItemUsers = usersBySprintItem.get(''+rawSprintItem.Id);
            if (sprintItemUsers == null) {
                sprintItemUsers = new List<UserAssignment>();
            }
            SprintItem sprintItem = new SprintItem(rawSprintItem, sprintItemUsers);

            if (itemMap.containsKey( sprintItem.status )) {
                itemMap.get( sprintItem.status ).add( sprintItem );
            } else {
                itemMap.get( SprintModel.NOT_STARTED_STATUS ).add( sprintItem );
            }
        }
    }

    public class SprintLane {
        public List<SprintItem> sprintItems {get; set;}
        public String status {get; set;}
        public String statusLabel {get; set;}
        public Decimal totalEffort {get; set;}
        public Decimal totalItems {get; set;}

        public SprintLane(String apiName, String label) {
            this.status = apiName;
            this.statusLabel = label;
            sprintItems = new List<SprintItem>();
            totalEffort = 0;
            totalItems = 0;
        }

        public void add(SprintItem sprintItem) {
            totalItems++;
            sprintItems.add( sprintItem );
            if ( sprintItem.backlogItem.effort != null) {
                totalEffort += sprintItem.backlogItem.effort;
            }
        }
    }

    public class SprintItem {

        public String id {get; set;}
        public BacklogItemModel backlogItem {get; set;}
        public String status {get; set;}
        public List<UserAssignment> users { get; set; }
        public String cardClass { get; set; }
        public Boolean hasUsers { get; set; }

        public SprintItem(Sprint_Item__c sprintItem, List<UserAssignment> users) {
            id     = sprintItem.Id;
            status = sprintItem.Status__c;
            this.users = users;
            backlogItem = new BacklogItemModel( sprintItem.Backlog__r );
            cardClass = 'x' + Math.min(3, users.size()) + '-users';
            hasUsers = users.size() > 0;
        }
    }

    public void addUser() {
        ALM_User__c almUser;
        try {
            almUser = ALMUserServices.getALMUser(selectedAlmUserId);
        } catch(ALMException ae) {
            ApexPages.addMessage(new Apexpages.Message(ApexPages.Severity.WARNING,  ae.getMessage()));
        }

        if (almUser != null) {
            sprintUsers.add(UserAssignment.create(Id.valueOf(model.sprintId), almUser));
        }
    }

    private List<UserAssignment> getExistingSprintUsers() {
        List<UserAssignment> users = new List<UserAssignment>();

        String query = 'SELECT Id, Sprint__c, ALM_User__c, ALM_User__r.Name, ALM_User__r.User__r.Name, Role__c, Role__r.Name';

        if (ALMUserServices.isChatterEnabled()) {
            query += ', ALM_User__r.User__r.SmallPhotoUrl';
        }

        query += ' FROM ' + SObjectServices.getFullyQualifiedName('Sprint_User__c');
        query += ' WHERE Sprint__c = \'' + String.escapeSingleQuotes(model.sprintId) +'\'';

        for (Sprint_User__c sprintUser : Database.query(query)) {
            users.add(new UserAssignment(sprintUser));
        }

        return users;
    }

    public System.PageReference save() {
        List<Sprint_User__c> sprintUsersToSave = new List<Sprint_User__c>();
        System.PageReference page = new System.PageReference('/apex/Sprint?id=' + sc.getId());
        page.setRedirect(true);

        for (UserAssignment sprintUser : sprintUsers) {
            if (String.isBlank(sprintUser.role)) {
                ApexPages.addMessage(new Apexpages.Message(ApexPages.Severity.ERROR,
                            System.Label.Backlog_User_Mgmt_Role_Required));
                return null;
            }
            sprintUsersToSave.add((Sprint_User__c) sprintUser.record);
        }

        System.Savepoint sp = Database.setSavepoint();

        if (!sprintUsersToDelete.isEmpty()) {
            try {
                delete sprintUsersToDelete;
                sprintUsersToDelete = new List<Sprint_User__c>();
            } catch (DMLException de) {
                System.debug(de);
                ApexPages.addMessage(new Apexpages.Message(ApexPages.Severity.ERROR,
                            System.Label.Generic_Error + ' \n'+ de.getMessage() ));
                return null;
            }
        }

        try {
            upsert sprintUsersToSave;
        } catch (DMLException de) {
            System.debug(de);
            ApexPages.addMessage(new Apexpages.Message(ApexPages.Severity.ERROR,
                        System.Label.Generic_Error + ' \n'+ de.getMessage()));
            Database.rollback(sp);
        }
        return page;
    }

    public void deleteUser() {
        for (Integer i = 0; i < sprintUsers.size(); i++) {

            if (sprintUsers[i].almUserId == selectedAlmUserId) {
                UserAssignment sprintUser = sprintUsers.remove(i);

                if (sprintUser.record.Id != null) {
                    sprintUsersToDelete.add((Sprint_User__c) sprintUser.record);
                }
                break;
            }
        }
    }
}