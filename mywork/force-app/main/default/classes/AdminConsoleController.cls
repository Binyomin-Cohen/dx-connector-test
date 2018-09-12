public with sharing class AdminConsoleController {

    public Boolean hasPermissions {get; set;}

    public AdminConsoleController() {
        hasPermissions = PermissionServices.checkPagePermissions(new AdminRolesPermissions()) == PermissionServices.PermissionLevel.FULL;
    }

    @RemoteAction
    public static List<ALM_User_Role__c> getAllRoles() {
        return ALMUserServices.getAllRoles();
    }

    /**
    * @throws ALMException
    */
    @RemoteAction
    public static List<ALM_User_Role__c> saveRoles(List<ALM_User_Role__c> rolesToUpsert, List<String> rolesIdsToDelete) {
        // Convert incoming role list into a map to handle incoming duplicates.
        Map<String, ALM_User_Role__c> rolesToUpsertMap = new Map<String, ALM_User_Role__c>();
        for (ALM_User_Role__c role : rolesToUpsert) {
            rolesToUpsertMap.put(role.Name.toUpperCase(), role);
        }

        // Extract role names from returned roles into a set.
        Set<String> existingRoleNames = new Set<String>();
        for (ALM_User_Role__c role : ALMUserServices.getRolesByName(rolesToUpsertMap.keySet())) {
            existingRoleNames.add(role.Name.toUpperCase());
        }

        // Remove any existing roles (matched by name) from the set of roles to upsert.
        for (String existingRoleName : existingRoleNames) {
            rolesToUpsertMap.remove(existingRoleName);
        }

        // Final conversion of role set back into a list for DML.
        rolesToUpsert = new List<ALM_User_Role__c>(rolesToUpsertMap.values());

        List<ALM_User_Role__c> rolesToDelete = new List<ALM_User_Role__c>();
        Map<Id, ALM_User_Role__c> existingRoles = new Map<Id, ALM_User_Role__c>(ALMUserServices.getRolesById(rolesIdsToDelete));
        for (String roleId : rolesIdsToDelete) {
            ALM_User_Role__c role = existingRoles.get(roleId);
            if (role == null) {
                continue;
            }
            else if (!role.Spint_Users__r.isEmpty() || !role.Backlog_Item_Users__r.isEmpty()) {
                throw new ALMException('An error occured during role deletion: you cannot delete roles with users assigned to it.');
            } else {
                rolesToDelete.add(role);
            }
        }

        try {
          delete rolesToDelete;
        } catch(System.DmlException de) {
            throw new ALMException('An error occured during role deletion'+ de.getMessage());
        }
        try {
          upsert rolesToUpsert;
        } catch(System.DmlException de) {
            throw new ALMException('An error occured during role save'+ de.getMessage());
        }

        return getAllRoles();
    }
}