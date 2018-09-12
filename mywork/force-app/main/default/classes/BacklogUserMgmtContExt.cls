global with sharing class BacklogUserMgmtContExt {

    private ApexPages.StandardController sc;
    private List<Backlog_User__c> backlogUsersToDelete;

    public String selectedAlmUserId {get; set;}

    public Boolean hasErrors {
        get {
            return ApexPages.hasMessages();
        }
    }

    public Integer permissionLevel {get; private set;}

    public List<UserAssignment> backlogUsers {get; set;}

    public BacklogUserMgmtContExt(ApexPages.StandardController sc) {
        this.sc = sc;
        backlogUsersToDelete = new List<Backlog_User__c>();
        permissionLevel = PermissionServices.checkPagePermissions(new BacklogUserMgmtPermissions()).ordinal();
    }

    public void addUser() {
        if (permissionLevel < PermissionServices.PermissionLevel.FULL.ordinal()) {
            ApexPages.addMessage(new Apexpages.Message(ApexPages.Severity.ERROR,  System.Label.Permissions_Error));
            return;
        }

        ALM_User__c almUser;
        try {
            almUser = ALMUserServices.getALMUser( selectedAlmUserId );
        } catch(ALMException ae) {
            ApexPages.addMessage( new Apexpages.Message(ApexPages.Severity.WARNING,  ae.getMessage()));
        }

        if (almUser != null) {
            backlogUsers.add(UserAssignment.create(Id.valueOf(sc.getId()), almUser));
        }
    }

    public void deleteUser() {
        if (permissionLevel < PermissionServices.PermissionLevel.FULL.ordinal()) {
            ApexPages.addMessage(new Apexpages.Message(ApexPages.Severity.ERROR,  System.Label.Permissions_Error));
            return;
        }

        for (Integer i = 0; i < backlogUsers.size(); i++) {

            if (backlogUsers[i].almUserId == selectedAlmUserId) {
                UserAssignment backlogUser = backlogUsers.remove(i);

                if (backlogUser.record.Id != null) {
                    backlogUsersToDelete.add((Backlog_User__c) backlogUser.record);
                }
                break;
            }
        }
    }

    public void save() {
        if (permissionLevel < PermissionServices.PermissionLevel.FULL.ordinal()) {
            ApexPages.addMessage(new Apexpages.Message(ApexPages.Severity.ERROR,  System.Label.Permissions_Error));
            return;
        }

        List<Backlog_User__c> backlogUsersToSave = new List<Backlog_User__c>();

        for (UserAssignment backlogUser : backlogUsers) {
            if (String.isBlank(backlogUser.role)) {
                ApexPages.addMessage(new Apexpages.Message(ApexPages.Severity.ERROR,
                            System.Label.Backlog_User_Mgmt_Role_Required));
                return;
            }
            backlogUsersToSave.add((Backlog_User__c) backlogUser.record);
        }

        System.Savepoint sp = Database.setSavepoint();

        if (!backlogUsersToDelete.isEmpty()) {
            try {
                delete backlogUsersToDelete;
                backlogUsersToDelete = new List<Backlog_User__c>();
            } catch (DMLException de) {
                System.debug(de);
                ApexPages.addMessage(new Apexpages.Message(ApexPages.Severity.ERROR,
                            System.Label.Generic_Error + ' \n'+ de.getMessage() ));
                return;
            }
        }

        try {
            upsert backlogUsersToSave;
        } catch (DMLException de) {
            System.debug(de);
            ApexPages.addMessage(new Apexpages.Message(ApexPages.Severity.ERROR,
                        System.Label.Generic_Error + ' \n'+ de.getMessage()));
            Database.rollback(sp);
        }
        loadBacklogUsers();
    }

    public void loadBacklogUsers() {
        backlogUsers = BacklogItemServices.getUserAssignments(sc.getId());
    }

    @RemoteAction
    global static List<ALM_User__c> getALMUsers() {
        return ALMUserServices.getAllUsers();
    }

    @RemoteAction
    global static List<ALM_User_Role__c> getUserRoles() {
        return ALMUserServices.getAllRoles();
    }

    /**
     * Deprecated. Use getALMUsers() instead.
     */
    @RemoteAction
    global static List<ALM_User__c> searchALMUsers(String s) {
        return new List<ALM_User__c>();
    }

    /**
     * Deprecated. Use getUserRoles() instead.
     */
    @RemoteAction
    global static List<ALM_User_Role__c> searchUserRoles(String s) {
        return new List<ALM_User_Role__c>();
    }
}