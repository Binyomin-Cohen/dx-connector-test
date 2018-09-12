/**
 * This class contains unit tests for validating the behavior of Apex classes
 * and triggers.
 *
 * Unit tests are class methods that verify whether a particular piece
 * of code is working properly. Unit test methods take no arguments,
 * commit no data to the database, and are flagged with the testMethod
 * keyword in the method definition.
 *
 * All test methods in an organization are executed whenever Apex code is deployed
 * to a production organization to confirm correctness, ensure code
 * coverage, and prevent regressions. All Apex classes are
 * required to have at least 75% code coverage in order to be deployed
 * to a production organization. In addition, all triggers must have some code coverage.
 * 
 * The @isTest class annotation indicates this class only contains test
 * methods. Classes defined with the @isTest annotation do not count against
 * the organization size limit for all Apex scripts.
 *
 * See the Apex Language Reference for more information about Testing and Code Coverage.
 */
@isTest
private class TestAssetDuplicatePreventer {

    static testMethod void testInserts() {
        Persona__c p = new Persona__c(Name='Build Manager');
        insert p;
        
        Backlog__c s = new Backlog__c(Persona__c=p.Id, User_Goal__c='to do something');
        insert s;
        
        Component__c c = new Component__c(Name='Test 1', Type__c='Apex Class');
        insert c;
        
        Backlog_Component__c sm1 = new Backlog_Component__c(Backlog__c=s.Id, Component__c=c.Id, Source_Sandbox__c='sandbox');
        insert sm1;
        
        Backlog_Component__c dupe = new Backlog_Component__c(Backlog__c=s.Id, Component__c=c.Id, Source_Sandbox__c='sandbox');
        
        try {
            insert dupe;
        } catch (Dmlexception e) {
            assertSingleComponent(e);
        }
    }
    
    static testMethod void testBulkInserts() {
        Persona__c p = new Persona__c(Name='Build Manager');
        insert p;
        
        Backlog__c s = new Backlog__c(Persona__c=p.Id, User_Goal__c='to do something');
        insert s;
        
        Component__c c1 = new Component__c(Name='Test 1', Type__c='Apex Class');
        Component__c c2 = new Component__c(Name='Test 2', Type__c='Apex Trigger');
        Component__c[] components = new Component__c[] {c1, c2};
        insert components;
        
        Backlog_Component__c sm1 = new Backlog_Component__c(Backlog__c=s.Id, Component__c=c1.Id, Source_Sandbox__c='sandbox');
        
        Backlog_Component__c sm2 = new Backlog_Component__c(Backlog__c=s.Id, Component__c=c2.Id, Source_Sandbox__c='sandbox');
        
        Backlog_Component__c[] members = new Backlog_Component__c[] {sm1, sm2};        
        insert members;
                
        Backlog_Component__c dupe1 = new Backlog_Component__c(Backlog__c=s.Id, Component__c=c1.Id, Source_Sandbox__c='sandbox');
        
        Backlog_Component__c dupe2 = new Backlog_Component__c(Backlog__c=s.Id, Component__c=c2.Id, Source_Sandbox__c='sandbox');
        
        Backlog_Component__c[] dupes = new Backlog_Component__c[] {dupe1, dupe2};        
        
        try {
            insert dupes;
        } catch (Dmlexception e) {
            assertMultipleComponents(e, 2);
        }
    }
    
    static testMethod void testUpdates() {
        Persona__c p = new Persona__c(Name='Build Manager');
        insert p;
        
        Backlog__c s = new Backlog__c(Persona__c=p.Id, User_Goal__c='to do something');
        insert s;
        
        Component__c c = new Component__c(Name='Test 1', Type__c='Apex Class');
        insert c;
        
        Backlog_Component__c sm1 = new Backlog_Component__c(Backlog__c=s.Id, Component__c=c.Id, Source_Sandbox__c='sandbox');
        insert sm1;
        
        sm1 = new Backlog_Component__c(Id=sm1.Id, Backlog__c=s.Id, Component__c=c.Id, Source_Sandbox__c='sandbox');
        
        try {
            update sm1;
        } catch (Dmlexception e) {
            assertSingleComponent(e);
        }
    }
    
    static testMethod void testBulkUpdates() {
        Persona__c p = new Persona__c(Name='Build Manager');
        insert p;
        
        Backlog__c s = new Backlog__c(Persona__c=p.Id, User_Goal__c='to do something');
        insert s;
        
        Component__c c1 = new Component__c(Name='Test 1', Type__c='Apex Class');
        Component__c c2 = new Component__c(Name='Test 2', Type__c='Apex Trigger');
        Component__c[] components = new Component__c[] {c1, c2};
        insert components;
        
        Backlog_Component__c sm1 = new Backlog_Component__c(Backlog__c=s.Id, Component__c=c1.Id, Source_Sandbox__c='sandbox');
        Backlog_Component__c sm2 = new Backlog_Component__c(Backlog__c=s.Id, Component__c=c2.Id, Source_Sandbox__c='sandbox');
        Backlog_Component__c[] members = new Backlog_Component__c[] {sm1, sm2};        
        insert members;
                
        sm1 = new Backlog_Component__c(Id=sm1.Id, Backlog__c=s.Id, Component__c=c1.Id, Source_Sandbox__c='sandbox');
        sm2 = new Backlog_Component__c(Id=sm2.Id, Backlog__c=s.Id, Component__c=c2.Id, Source_Sandbox__c='sandbox');
        Backlog_Component__c[] membersToUpdate = new Backlog_Component__c[] {sm1, sm2};        
        
        try {
            update membersToUpdate;
        } catch (Dmlexception e) {
            assertMultipleComponents(e, 2);
        }
    }
    
    static void assertSingleComponent(System.DMLException e) {
        System.assert(e.getNumDml() == 1);
    }
    
    static void assertMultipleComponents(DMLException e, Integer numberOfFailedRecords) {
        for (Integer i=0; i<numberOfFailedRecords; i++) {
            System.assert(e.getNumDml() == numberOfFailedRecords);
        }
    }
 
}