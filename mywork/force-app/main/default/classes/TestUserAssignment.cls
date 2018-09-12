@isTest
private class TestUserAssignment {
    static testMethod void create() {
        ALM_User__c user = new ALM_User__c(First_Name__c = 'Foo', Last_Name__c = 'Manchoo');
        Backlog__c backlog = new Backlog__c();
        Sprint__c sprint = new Sprint__c();

        insert user;
        insert backlog;
        insert sprint;

        Test.startTest();
            UserAssignment backlogUser = UserAssignment.create(backlog.Id, user);
            UserAssignment sprintUser = UserAssignment.create(sprint.Id, user);

            System.assertEquals(Backlog_User__c.SObjectType, backlogUser.record.getSObjectType(),
                    'The factory method should create the appropriate kind of record.');

            System.assertEquals(Sprint_User__c.SObjectType, sprintUser.record.getSObjectType(),
                    'The factory method should create the appropriate kind of record.');

            Boolean caught = false;
            try {
                UserAssignment invalidUser = UserAssignment.create(user.Id, user);
            } catch (ALMException e) {
                caught = true;
            }

            System.assert(caught, 'An exception should be thrown if the incorrect object type is used.');
        Test.stopTest();
    }
}