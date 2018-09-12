public with sharing class ALMUserServices {
    public static final String DEFAULT_USER_IMAGE_URL = '/profilephoto/005/T';


    public static Boolean isChatterEnabled() {
        //TODO: figure out how to test ConnectApi.Organization.getSettings().features.chatter and use that approach
        return Schema.SObjectType.User.isFeedEnabled();
    }

    public static List<ALM_User__c> searchALMUsers(String searchTarget)
    {
        String searchString =
             (searchTarget == null) ? '%' : '%' + String.escapeSingleQuotes( searchTarget.trim() ) + '%';

        String query = getALMUserQuery();

        query += ' WHERE Name like :searchString ';
        query += 'ORDER BY Name ';

        return Database.query( query );
    }

    public static List<ALM_User__c> getAllUsers() {
        return Database.query(getALMUserQuery() + ' ORDER BY Name');
    }

    public static List<ALM_User_Role__c> searchUserRoles(String searchTarget) {
        String searchString =
             (searchTarget == null) ? '%' : '%' + String.escapeSingleQuotes( searchTarget.trim() ) + '%';

        String query = 'SELECT Name';
        query += ' FROM '+ SObjectServices.getFullyQualifiedName( 'ALM_User_Role__c' );
        query += ' WHERE Name like :searchString';
        query += ' ORDER BY Name ';

        return Database.query( query );
    }

    public static List<ALM_User_Role__c> getAllRoles() {
        return [
            SELECT Id, Name,
             (SELECT Id FROM Spint_Users__r LIMIT 1),
             (SELECT Id FROM Backlog_Item_Users__r LIMIT 1)
            FROM ALM_User_Role__c
            ORDER BY Name
        ];
    }

    public static List<ALM_User_Role__c> getRolesById(List<String> roleIds) {
        Set<String> roles = new Set<String>(roleIds);
        return [
            SELECT Id, Name,
             (SELECT Id FROM Spint_Users__r LIMIT 1),
             (SELECT Id FROM Backlog_Item_Users__r LIMIT 1)
            FROM ALM_User_Role__c
            WHERE Id IN :roleIds
            ORDER BY Name
        ];
    }

    // This method probably would not be necessary if Set implemented Iterable...
    public static List<ALM_User_Role__c> getRolesByName(List<String> roleNames) {
        return getRolesByName(new Set<String>(roleNames));
    }

    public static List<ALM_User_Role__c> getRolesByName(Set<String> roleNames) {
        return [
            SELECT Name
            FROM ALM_User_Role__c
            WHERE Name IN :roleNames
        ];
    }

    public static ALM_User__c getALMUser(Id almUserId) {

        String query = ALMUserServices.getALMUserQuery();

        query += ' WHERE Id = :almUserId ';

        List<ALM_User__c> almUsers = Database.query( query );
        if(almUsers.isEmpty()) {
            //TODO: replace with label
        	throw new ALMException( 'Invalid User Id.' );
        }
        else {
            return almUsers[0];
        }
    }

    private static String getALMUserQuery() {
        String query = 'SELECT Id, Name, User__r.Name';

        if ( ALMUserServices.isChatterEnabled() ) {
            query += ', User__r.SmallPhotoUrl ';
        }

        query += ' FROM ' + SObjectServices.getFullyQualifiedName( 'ALM_User__c' );

        return query;
    }
}