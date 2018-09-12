public with sharing class UserAssignment {

    public SObject record    {get; set;}
    public String  name      {get; set;}
    public String  almUserId {get; set;}
    public String  photoURL  {get; set;}

    public String  role {
        get {
            return (String) record.get(SObjectServices.getFullyQualifiedName('Role__c'));
        }
        set {
            record.put(SObjectServices.getFullyQualifiedName('Role__c'), value);
        }
    }

    public String roleDisplay {
        get {

            if (String.isNotBlank(roleDisplay)) {
                return roleDisplay;
            } else if (String.isBlank(role)) {
                return 'Assign Role';
            } else {
                sObject  role =  record.getSObject(SObjectServices.getFullyQualifiedName('Role__r'));
                return (role == null) ? 'Assign Role' : (String)role.get('Name');
            }
        }
        set;
    }

    public String roleName {
        get {
            sObject  role =  record.getSObject(SObjectServices.getFullyQualifiedName('Role__r'));
            return (role == null) ? '' : (String)role.get('Name');
        }
        set;
    }

    /**
     * For existing user assignments
     * @param  record  A Backlog_User__c or a Sprint_User__c
     */
    public UserAssignment(SObject record) {
        this(record, (ALM_User__c) record.getSObject('ALM_User__r'));
    }

    /**
     * @param   record  A Sprint_User__c or a Backlog_User__c
     * @param   user    an ALM_User__c
     */
    private UserAssignment(SObject record, ALM_User__c user) {

        this.record = record;
        this.almUserId = user.Id;
        this.name = user.Name;

        if (user.User__r != null && ALMUserServices.isChatterEnabled()) {
            SObject relatedUser = user.getSObject('User__r');
            photoURL = String.valueOf( relatedUser.get('SmallPhotoUrl') );
        } else {
            photoURL = ALMUserServices.DEFAULT_USER_IMAGE_URL;
        }
    }

    /**
     * @param   targetId    A Sprint__c or a Backlog__c
     * @param   user        An ALM_User__c
     */
    public static UserAssignment create(Id targetId, ALM_User__c user) {
        if (targetId.getSObjectType() == Backlog__c.SObjectType) {
            return new UserAssignment(new Backlog_User__c(Backlog__c = targetId, ALM_User__c = user.Id), user);
        } else if (targetId.getSObjectType() == Sprint__c.SObjectType) {
            return new UserAssignment(new Sprint_User__c(Sprint__c = targetId, ALM_User__c = user.Id), user);
        } else {
            throw new ALMException('Invalid user assignment type.');
        }

        return null;
    }
}