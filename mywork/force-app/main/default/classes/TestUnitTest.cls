/**
 * The tests for the library to facilitate writing quality unit tests.
 *
 * @author Krishna Kollu
 * @version 1.5, 5/6/2015
*/
@isTest
public class TestUnitTest {
    static UnitTest.DataGenerator acct = new AccountDG();
    static UnitTest.DataGenerator leads = new LeadDG();
    static UnitTest.DataGenerator grp = new GroupDG();
    static UnitTest.DataGenerator opportunities = new OpportunityDG();
    static Integer offset = 0;
    static String sampleName = 'sampleName';
    static Integer BULK_NUMBER = 20;
    
    static Set<ID> preexistingGroups;

    static DateTime pastHour = DateTime.now().addHours(-1);
     
    static
    {
        preexistingGroups = new Set<ID>();
        for(Release__c g : [Select ID From Release__c Where CreatedDate>:pastHour])
        {
            preexistingGroups.add(g.ID);
        } 
    }
    
    public class AccountDG implements UnitTest.DataGenerator
    { 
        public List<SObject> generateData(Integer howMany)
        {
            List<Backlog__c> accts = new List<Backlog__c>();
            for(Integer i = 0; i < howMany; i++)
            {
                accts.add(new Backlog__c());
            }
            return accts;
        } 
    }
    
    public class OpportunityDG implements UnitTest.DataGenerator
    { 
        public List<SObject> generateData(Integer howMany)
        {
            List<Deployment_Attempt__c> optys = new List<Deployment_Attempt__c>();
            for(Integer i = 0; i < howMany; i++)
            {
                optys.add(new Deployment_Attempt__c());
            }
            return optys;
        } 
    }
    
    public class LeadDG implements UnitTest.DataGenerator
    { 
        public List<SObject> generateData(Integer howMany)
        {
            List<Project__c> lds = new List<Project__c>();
            for(Integer i = 0; i < howMany; i++)
            {
                lds.add(new Project__c());
            }
            return lds;
        } 
    }
    
    public class GroupDG implements UnitTest.DataGenerator
    { 
        public List<SObject> generateData(Integer howMany)
        {
            List<Release__c> lds = new List<Release__c>();
            for(Integer i = 0; i < howMany; i++)
            {
                lds.add(new Release__c(Name='Group'+offset));
                offset++;
            }
            return lds;
        } 
    }
    
    static testMethod void testInsertAllException()
    {
        UnitTest.createTestData(acct).many(5).tag('Common Tag');
        UnitTest.createTestData(grp).many(5).tag('Common Tag');
        
        Boolean exceptionFound = false;
        try
        {
            UnitTest.get('Common Tag').insertAll();
        }
        catch(UnitTest.DatabaseOperationException e)
        {
            exceptionFound = true;
        }
        
        System.assert(exceptionFound,'InsertAll must return an exception when the developer tries to insert objects of the same sobject type');
    }
    
    static testMethod void testInsertAll()
    {
        Integer numAccounts = 100;
        Integer numGroups = 200;
        UnitTest.createTestData(acct).many(numAccounts);
        UnitTest.createTestData(grp).many(numGroups).insertAll();
        
        List<Backlog__c> accts = [Select ID From Backlog__c];
        List<Release__c> groups = [Select ID From Release__c Where ID NOT IN: preexistingGroups AND CreatedDate>:pastHour];
        System.assertEquals(0,accts.size(),'We do not insert any items that are not in the context of our insertion');
        System.assertEquals(numGroups,groups.size(),'We expect to insert all items that are not in the context of our insertion');
    }
    
    static testMethod void updateAllException()
    {
        UnitTest.createTestData(grp).many(10).insertAll();
        UnitTest.addData([Select ID From User Where IsActive=True Limit 1]);
         
        Boolean exceptionFound = false;
        try
        {
           UnitTest.allData().updateAll();
        }
        catch(UnitTest.DatabaseOperationException e)
        {
            exceptionFound = true;
        }  
        System.assert(exceptionFound,'The developer cannot attempt to update two different kind of objects in one call of updateAll');
        
    }
    
    static testMethod void updateAll()
    {
        final String newValue = 'C';
        Release__c firstGroup = new Release__c(Name='Group One');
        Release__c secondGroup = new Release__c(Name='Group Two');
        List<Release__c> groups = new List<Release__c> {firstGroup, secondGroup};
        insert groups;
        
        final String newNameGroupOne = 'Updated Group One';
        final String newNameGroupTwo = 'Updated Group One';
        
        firstGroup.Name = newNameGroupOne;
        secondGroup.Name = newNameGroupTwo;
        
        UnitTest.addData(groups).updateAll();
        
        groups = [Select ID, Name From Release__c Where ID NOT IN: preexistingGroups AND CreatedDate>:pastHour];
        System.assertEquals(2,groups.size(),'We expect the update operation to not delete any records');
        for(Release__c g : groups)
        {
            if(g.Id==firstGroup.Id)
            {
                System.assertEquals(newNameGroupOne,g.Name,'We expect the update operation to successfully work');
            }
            else
            {
                System.assertEquals(newNameGroupTwo,g.Name,'We expect the update operation to successfully work');
            }
        }
    }
    
    static testMethod void deleteAll()
    {
        Release__c firstGroup = new Release__c(Name='Group One');
        Release__c secondGroup = new Release__c(Name='Group Two');
        List<Release__c> groups = new List<Release__c> {firstGroup, secondGroup};
        insert groups;
        
        UnitTest.addData(groups).deleteAll();
        
        groups = [Select ID From Release__c Where ID NOT IN: preexistingGroups AND CreatedDate>:pastHour];
        System.assertEquals(0,groups.size(),'We expect the delete operation to successfully work');
    }
    
    static testMethod void deleteAllException()
    {
        UnitTest.createTestData(grp).many(10).insertAll();
        UnitTest.addData([Select ID From User Where IsActive=True Limit 1]);
        
        Boolean exceptionFound = false;
        try
        {
           UnitTest.allData().deleteAll();
        }
        catch(UnitTest.DatabaseOperationException e)
        {
            exceptionFound = true;
        }  
        System.assert(exceptionFound,'The developer cannot attempt to delete two different kind of objects in one call of updateAll');
        
    }
    
    static testMethod void testInsertGetSObject()
    {
        Integer numAccounts = BULK_NUMBER;
        Integer numGroups = BULK_NUMBER/2;
        UnitTest.createTestData(acct).many(numAccounts);
        UnitTest.createTestData(grp).many(numGroups);
        
        UnitTest.get(Release__c.SObjectType).insertAll();
        
        List<Backlog__c> accts = [Select ID from Backlog__c];
        List<Release__c> groups = [Select ID From Release__c Where ID NOT IN: preexistingGroups AND CreatedDate>:pastHour];
        System.assertEquals(0,accts.size(),'We do not insert any items that are not in the context of our insertion');
        System.assertEquals(numGroups,groups.size(),'We expect to insert all items that are not in the context of our insertion');
    }
     
    static testMethod void testmany() { 
        Integer sampleNumber = BULK_NUMBER;
        List<Backlog__c> accts = (List<Backlog__c>) UnitTest.createTestData(acct).many(sampleNumber).getList();
        System.assertEquals(sampleNumber, accts.size(), 'Bulkify should create the right number of sobjects');
    }
    
    static testMethod void testAssign() { 
        Integer sampleNumber = BULK_NUMBER;
        
        List<Backlog__c> accts = (List<Backlog__c>) UnitTest.createTestData(acct).many(sampleNumber).assign(SObjectServices.getFullyQualifiedName('Summary__c'),'GA').getList();
        
        System.assertEquals(sampleNumber, accts.size(), 'Assign shoiuld not delete any accounts');
        for(Backlog__c a : accts)
        {
            System.assertEquals('GA',a.Summary__c,'When we assign a value into a certain field, we expect to find that value for that field for all the specified objects');
        } 
    }
    
    static testMethod void testGetIds()
    {
        Integer sampleNumber = 10;
        UnitTest.createTestData(acct).many(sampleNumber).divide(2).part('Group One').part('Group Two');
        UnitTest.get(Backlog__c.SObjectType).dummyInsert();
        
        Test.startTest();
            Set<ID> ids = UnitTest.getIds('Group One');
        Test.stopTest();
        
        System.assertEquals(Pluck.ids(UnitTest.get('Group One').getList()),ids,'GetIDs extracts the ids of the given tag');
    }
    
    static testMethod void testGetIds_InvalidTag()
    {
        Integer sampleNumber = 10;
        UnitTest.createTestData(acct).many(sampleNumber).tag('Hello');
        
        Boolean exceptionFound = false;
        try
        {
            UnitTest.getIds('Hel');
        }
        catch(UnitTest.InvalidTagException e)
        {
            exceptionFound = true;
        }
        
        System.assert(exceptionFound,'We should get an invalid tag exception when we try to get objects that match an invalid tag. An invalid tag is a tag that has been not been assigned to any object yet in the flow of the unit test.');
    }
    
    static testMethod void testGet_InvalidTag()
    {
        Integer sampleNumber = 10;
        UnitTest.createTestData(acct).many(sampleNumber).tag('Hello');
        
        Boolean exceptionFound = false;
        try
        {
            UnitTest.get('Hel');
        }
        catch(UnitTest.InvalidTagException e)
        {
            exceptionFound = true;
        }
        
        System.assert(exceptionFound,'We should get an invalid tag exception when we try to get objects that match an invalid tag. An invalid tag is a tag that has been not been assigned to any object yet in the flow of the unit test.');
    }
    
    static testMethod void testMinus_InvalidTag()
    {
        Integer sampleNumber = 10;
        UnitTest.createTestData(acct).many(sampleNumber).tag('Hello');
        
        Boolean exceptionFound = false;
        try
        {
            UnitTest.allData().minus('Hel');
        }
        catch(UnitTest.InvalidTagException e)
        {
            exceptionFound = true;
        }
        
        System.assert(exceptionFound,'We should get an invalid tag exception when we try to minus objects that match an invalid tag. An invalid tag is a tag that has been not been assigned to any object yet in the flow of the unit test.');
    }
     
    static testMethod void testInvalidTagCharacters()
    {
        for(String illegalCharacter : UnitTest.illegalCharacters)
        {
            testInvalidTagCharacter(illegalCharacter);
        }
    }
    static void testInvalidTagCharacter(String invalidCharacter)
    {
        testInvalidTagCharacterOnTag(invalidCharacter);
        testInvalidTagCharacterOnPart(invalidCharacter);
    }
    static void testInvalidTagCharacterOnTag(String invalidCharacter)
    {
        Integer sampleNumber = 10;
        
        Boolean exceptionFound = false;
        try
        {
            UnitTest.createTestData(acct).many(sampleNumber).tag('Hello' + invalidCharacter);
        }
        catch(UnitTest.IllegalCharactersException e)
        {
            exceptionFound = true;
        }
        
        System.assert(exceptionFound,'We should get an invalid characters exception because there is an invalid character "' + invalidCharacter + '" in the tag name');
    }
    
    static void testInvalidTagCharacterOnPart(String invalidCharacter)
    {
        Integer sampleNumber = 10;
        
        Boolean exceptionFound = false;
        try
        {
            UnitTest.createTestData(acct).many(sampleNumber).divide(1).part('Hello' + invalidCharacter);
        }
        catch(UnitTest.IllegalCharactersException e)
        {
            exceptionFound = true;
        }
        
        System.assert(exceptionFound,'We should get an invalid characters exception because there is an invalid character "' + invalidCharacter + '" in the tag name');
    }
    
    static testMethod void testTagging() {
        Integer numAccounts = BULK_NUMBER;
        Integer numLeads = BULK_NUMBER*2;
        UnitTest.createTestData(acct).many(numAccounts).tag('Sample Tag').tag('Star Wars');
        UnitTest.createTestData(leads).many(numLeads).tag('Sample Tag 2').tag('Star Wars');
        List<SObject> sampleTagObjects = UnitTest.get('sample tag').getList();
        List<SObject> sampleTag2Objects = UnitTest.get('Star Wars').filter('sample tag 2').getList();
        List<SObject> starWarsObjects = UnitTest.get('Star Wars').getList();
        List<SObject> starWarsMinusSampleTag2 = UnitTest.get('Star Wars').minus('sample tag 2').getList();
        
        System.assertEquals(numAccounts, sampleTagObjects.size(), 'When we search for a tag, we expect to get back the right number of objects.');
        for(SObject o : sampleTagObjects)
        {
            System.assert(o instanceOf Backlog__c, 'Every object tagged as "sample tag" is an account. We search to see if an object matches a whole tag, so even though "sample tag" is a substring of "sample tag 2" we will not get back any objects for tag "sample tag 2"');
        }
        System.assertEquals(numLeads, sampleTag2Objects.size(),'When we search for a tag, we expect to get back the right number of objects.');
        for(SObject o : sampleTag2Objects)
        {
            System.assert(o instanceOf Project__c, 'Every object tagged as "sample tag 2" is a lead');
        }
        System.assertEquals(numAccounts+numLeads, starWarsObjects.size(),'When we search for a tag, we expect to get back the right number of objects.');
        System.assertEquals(numAccounts, starWarsMinusSampleTag2.size(), 'When we minus a tag, we will not get back any objects that have that tag.');
        for(SObject o : starWarsMinusSampleTag2)
        {
            System.assert(o instanceOf Backlog__c, 'Every object tagged as "sample tag 2" is a lead. Therefore when we minused "sample tag 2" from a context of dataitems that had both accounts and leads, we will no longer get back the leads');
        }
    }
    static testMethod void testSingle() { 
        List<Backlog__c> accts = (List<Backlog__c>) UnitTest.createTestData(acct).single().getList();
        System.assertEquals(1, accts.size(), 'Single should create only 1 sobject');
    }
    
    static testMethod void testDivideEvenNumber()
    {
        Integer numAccounts = 100;
        
        UnitTest.createTestData(acct).many(numAccounts).divide(2).part('Left Division')
                                                                    .part('Remaining Division');
                                                                    
        Integer numLeftDivisionAccounts = UnitTest.get('Left Division').getList().size();
        Integer numRemainingDivisionAccounts = UnitTest.get('Remaining Division').getList().size();
        Integer countAccounts = numLeftDivisionAccounts+numRemainingDivisionAccounts;
        
        System.assert(numLeftDivisionAccounts>0,'Each division must have at least one element');
        System.assert(numRemainingDivisionAccounts>0,'Each division must have at least one element');
        System.assertEquals(numAccounts,countAccounts,'All divisions must add up to the total number of elements divided');
    }
    
    static testMethod void testDivideOddNumber()
    {
        Integer numAccounts = 111;
        
        UnitTest.createTestData(acct).many(numAccounts).divide(3).part('Left Division')
                                                                    .part('Center Division')
                                                                    .part('Right Division');
        
        
        Integer numLeftDivisionAccounts = UnitTest.get('Left Division').getList().size();
        Integer numCenterDivisionAccounts = UnitTest.get('Center Division').getList().size();
        Integer numRightDivisionAccounts = UnitTest.get('Right Division').getList().size(); 
        Integer countAccounts = numLeftDivisionAccounts+numCenterDivisionAccounts+numRightDivisionAccounts;
        
        System.assert(numLeftDivisionAccounts>0,'Each division must have at least one element');
        System.assert(numCenterDivisionAccounts>0,'Each division must have at least one element');
        System.assert(numRightDivisionAccounts>0,'Each division must have at least one element');
        System.assertEquals(numAccounts,countAccounts,'All divisions must add up to the total number of elements divided');
    }
    
    static testMethod void testDivideByOne()
    {
        UnitTest.createTestData(acct).single().divide(1).part('Only Division');
        
        Integer countAccounts = UnitTest.get('Only Division').getList().size();
        System.assertEquals(1,countAccounts,'All divisions must add up to the total number of elements divided');
    }
    
    static testMethod void testDivideByZero()
    {
        Boolean exceptionFound = false;
        try
        {
            UnitTest.createTestData(acct).single().divide(0).part('Only Division');
        }
        catch(UnitTest.DividingException e)
        {
            exceptionFound = true;
        }
        
        System.assert(exceptionFound, 'The divide function must not permit divisions by 0');
    }
    
    static testMethod void testDivideByNegativeNumber()
    {
        Boolean exceptionFound = false;
        try
        {
            UnitTest.createTestData(acct).single().divide(-1).part('Only Division');
        }
        catch(UnitTest.DividingException e)
        {
            exceptionFound = true;
        }
        
        System.assert(exceptionFound, 'The divide function must not permit divisions by a negative number');
    }
    
    static testMethod void testTooManyDivisions()
    {
        Boolean exceptionFound = false;
        try
        {
            UnitTest.createTestData(acct).many(20).divide(21);
        }
        catch(UnitTest.DividingException e)
        {
            exceptionFound = true;
        }
        
        System.assert(exceptionFound, 'The divide function must not permit divisions by a greater number than the size of the elements to be divided');
    }
    
    static testMethod void testTooManyPartsCalled()
    {
        Boolean exceptionFound = false;
        try
        {
            UnitTest.createTestData(acct).many(40).divide(4).part('1').part('2').part('3').part('4').part('5');
        }
        catch(UnitTest.DividingException e)
        {
            exceptionFound = true;
        }
        
        System.assert(exceptionFound, 'The part function fails when you call it more times for a division that the number of divisions you specified');
    }
    
    static testMethod void testGetByObjectTypeException()
    {
        Boolean exceptionFound = false;
        try
        {
            UnitTest.get(Release__c.SObjectType);
        }
        catch(UnitTest.InvalidTagException e)
        {
            exceptionFound = true;
        }   
        
        System.assert(exceptionFound,'When we try to select objects of a type that does not exist in our test objects, we expect to warn the developer via an error');
    }
    
    static testMethod void testFilterByObjectTypeException()
    {
        Boolean exceptionFound = false;
        try
        {
            UnitTest.allData().filter(Release__c.SObjectType);
        }
        catch(UnitTest.InvalidTagException e)
        {
            exceptionFound = true;
        }   
        
        System.assert(exceptionFound,'When we try to filter objects of a type that does not exist in our test objects, we expect to warn the developer via an error');
    }
    
    static testMethod void testAssertEquivalence_AssertionPasses()
    {
        final String failFilterTag = 'FailFilter';
        UnitTest.createTestData(grp).many(BULK_NUMBER*2).divide(2).part('Groups Fail Filter').part('Groups Pass Filter');
        UnitTest.get('Groups Fail Filter').assign('Name',failFilterTag);
        UnitTest.get('Groups Pass Filter').assign('Name',sampleName);
        UnitTest.get(Release__c.SObjectType).insertAll();
        
        List<Release__c> filteredGroups = [Select ID, Name From Release__c Where Name=:sampleName And ID Not IN:preexistingGroups AND CreatedDate>:pastHour];
        List<Release__c> groupsFailedFilter = [Select ID, Name From Release__c Where Name=:failFilterTag And ID Not IN:preexistingGroups AND CreatedDate>:pastHour];
        
        
        
        try
        { 
            UnitTest.analyze('Groups Pass Filter').assertEquivalence(filteredGroups,'');
            UnitTest.analyze('Groups Pass Filter').assertEquivalence(filteredGroups,'');
            UnitTest.analyze('Groups Fail Filter').assertEquivalence(groupsFailedFilter,'');
        }
        catch(UnitTest.AssertionException e)
        {
            System.assert(false,'The assertion should have passed. Instead we got this: ' + e);
        }
    }
    
    static String setupAssertEquivalence(Boolean insertThem, String name)
    {
        UnitTest.createTestData(grp).many(50).divide(2).part('Groups Fail Filter').part('Groups Pass Filter');
        UnitTest.get('Groups Fail Filter').assign('Name','FailFilter');
        UnitTest.get('Groups Pass Filter').assign('Name',name);
        if(insertThem) UnitTest.get(Release__c.SObjectType).insertAll();
        return 'Groups Pass Filter';
    }
    
    static void assetEquivalenceAssertionFails(List<Release__c> filteredGroups, String tagOfExpectedObjectsToPassFilter, String message, Boolean analyzeExceptionExpected)
    {
        Boolean exceptionFound = false;
        
        try
        {
            UnitTest.analyze(tagOfExpectedObjectsToPassFilter).assertEquivalence(filteredGroups,'');
        }
        catch(UnitTest.AssertionException e)
        {
            if(!analyzeExceptionExpected) exceptionFound = true;
        }
        catch(UnitTest.AnalyzeException a)
        {
            if(analyzeExceptionExpected) exceptionFound = true;
        }
        System.assert(exceptionFound, message);
    }
    
    static testMethod void testAssertEquivalence_AssertionFails_SizeIssue()
    {
        String tagOfExpectedObjectsToPassFilter = setupAssertEquivalence(true, sampleName);
        
        List<Release__c> incorrectlyFilteredGroups = [Select ID, Name From Release__c Where Name=:sampleName Limit 1];
        
        assetEquivalenceAssertionFails(incorrectlyFilteredGroups,tagOfExpectedObjectsToPassFilter, 'We expect the equivalence assertion to fail because the size of the context and the size of the compared list are not the same',false);
    }
    
    static testMethod void testAssertEquivalence_AssertionFails_NotEquivalent()
    {
        String tagOfExpectedObjectsToPassFilter = setupAssertEquivalence(true, sampleName);
        
        List<Release__c> incorrectlyFilteredGroups = [Select ID, Name From Release__c Where Name!=:sampleName And ID Not IN:preexistingGroups AND CreatedDate>:pastHour];
        
        assetEquivalenceAssertionFails(incorrectlyFilteredGroups, tagOfExpectedObjectsToPassFilter, 'We expect the equivalence assertion to fail because the ids of elements of the context are not contained in the ids of the elements in the list',false);
    }
    
    static testMethod void testAssertEquivalence_AssertionFails_NullIDIssue()
    {
        String tagOfExpectedObjectsToPassFilter = setupAssertEquivalence(true, sampleName);
        
        List<Release__c> incorrectlyFilteredGroups = [Select ID, Name From Release__c Where Name=:sampleName And ID Not IN:preexistingGroups AND CreatedDate>:pastHour];
        incorrectlyFilteredGroups[0].ID=null;
        
        assetEquivalenceAssertionFails(incorrectlyFilteredGroups, tagOfExpectedObjectsToPassFilter, 'We expect the equivalence assertion to fail because one of the elements in the compared list has a null ID',false);
    }
    
    static testMethod void testAssertEquivalence_AssertionFails_NullIDInContextIssue()
    {
        String tagOfExpectedObjectsToPassFilter = setupAssertEquivalence(true, sampleName);
        UnitTest.get(tagOfExpectedObjectsToPassFilter).divide(2).part('Objects without ID').part('Objects with ID');
        UnitTest.get('Objects without ID').assign('ID',null);
        
        List<Release__c> correctlyFilteredGroups = [Select ID, Name From Release__c Where Name=:sampleName And ID Not IN:preexistingGroups AND CreatedDate>:pastHour];
        
        assetEquivalenceAssertionFails(correctlyFilteredGroups, tagOfExpectedObjectsToPassFilter, 'We expect the equivalence assertion to fail because at least one of the elements in the context has a null ID, because it was not inserted',true);
    }
    
    static testMethod void testTaggingSameTag()
    {
        final Integer NUM_GROUPS = BULK_NUMBER*5;
        UnitTest.createTestData(grp).many(NUM_GROUPS).tag('Same Tag').tag('Same Tag');
        Test.startTest();
            List<Release__c> grps = UnitTest.get('Same Tag').getList();
        Test.stopTest();
        
        System.assertEquals(NUM_GROUPS,grps.size(),'We expect to get back the right number of groups');
    }
    
     static testMethod void testAssignFromTag_WholeSpan()
    {
        UnitTest.createTestData(grp).many(4).tag('Marketing Queues').insertAll();
        UnitTest.createTestData(leads).many(3).property('OwnerID').assignFrom('Marketing Queues');
        UnitTest.createTestData(leads).many(3).property('OwnerID').assignFrom('Marketing Queues');
        UnitTest.createTestData(leads).many(3).property('OwnerID').assignFrom('Marketing Queues');
        Map<ID, Integer> ownerEncounteredToFrequency = new Map<ID, Integer>();
        for(Project__c l : (List<Project__c>) UnitTest.get(Project__c.SObjectType).getList())
        {
            if(ownerEncounteredToFrequency.containsKey(l.OwnerID))
            {
                ownerEncounteredToFrequency.put(l.OwnerID,ownerEncounteredToFrequency.get(l.OwnerID)+1);
            }
            else
            {
                ownerEncounteredToFrequency.put(l.OwnerID,1);
            }
        }
        
        Boolean thirdRepeatFound = false;
        for(ID ownerID : ownerEncounteredToFrequency.keySet())
        {
            if(ownerEncounteredToFrequency.get(ownerID)==3) 
            {
                System.assert(!thirdRepeatFound, 'We will only have one of the ownerID assignments repeat three times');
                thirdRepeatFound = true;
            }
            else 
            {
                System.assertEquals(2,ownerEncounteredToFrequency.get(ownerID),'If an ownerID assignment does not repeat three times, it must repeat just two times');
            }
        }
        System.assert(thirdRepeatFound,'One of the ownerID assignments must repeat three times, based on how often we called the assign function');
    }
    
    static testMethod void testAssignFrom_WholeSpan()
    {
        Set<String> specifiedValues = new Set<String> {'Regular','Role','Case','Lead'};
        UnitTest.createTestData(grp).many(2).property(SobjectServices.getFullyQualifiedName('Status__c')).assignFrom(new List<String>(specifiedValues)); //Possibly Get Regular and Role
        UnitTest.createTestData(grp).many(2).property(SobjectServices.getFullyQualifiedName('Status__c')).assignFrom(new List<String>(specifiedValues)); //Possibly Get Case and Lead
        UnitTest.createTestData(grp).many(1).property(SobjectServices.getFullyQualifiedName('Status__c')).assignFrom(new List<String>(specifiedValues)); //Possibly Get Regular
        UnitTest.createTestData(grp).many(4).property(SobjectServices.getFullyQualifiedName('Status__c')).assignFrom(new List<String>(specifiedValues)); //Possibly Get Role, Case, Lead, and Regular

        Map<String, Integer> typesEncounteredToFrequency = new Map<String, Integer>();
        for(Release__c g : (List<Release__c>) UnitTest.get(Release__c.SObjectType).getList())
        {
            if(typesEncounteredToFrequency.containsKey(g.Status__c))
            {
                typesEncounteredToFrequency.put(g.Status__c,typesEncounteredToFrequency.get(g.Status__c)+1);
            }
            else
            {
                typesEncounteredToFrequency.put(g.Status__c,1);
            }
        }
        
        Boolean thirdRepeatFound = false;
        for(String gType : typesEncounteredToFrequency.keySet())
        {
            if(typesEncounteredToFrequency.get(gType)==3) 
            {
                System.assert(!thirdRepeatFound, 'We will only have one of the group types repeat three times');
                thirdRepeatFound = true;
            }
            else 
            {
                System.assertEquals(2,typesEncounteredToFrequency.get(gType),'If a group type does not repeat three times, it must repeat just two times');
            }
        }
        System.assert(thirdRepeatFound,'One of the group types must repeat three times based on how often we called the assign function');
    }
    
    static testMethod void testAssignFrom_ByTag_InvalidTag()
    {
        Boolean exceptionFound = false;
        try
        {
            UnitTest.createTestData(grp).many(10).property(SobjectServices.getFullyQualifiedName('Status__c')).assignFrom('Non Existing Tag');
        }
        catch(UnitTest.InvalidTagException e)
        {
            exceptionFound = true;
        }
        
        System.assert(exceptionFound, 'The developer must be prevented from using an invalid tag that has never been assigned to any object');
    }
    
    static testMethod void testAssignFrom_ByTag_InvalidAssignment()
    {
        Boolean exceptionFound = false;
        try
        {
            UnitTest.createTestData(grp).many(4).tag('Marketing Queues');
            UnitTest.createTestData(leads).many(8).property('OwnerID').assignFrom('Marketing Queues');
        }
        catch(UnitTest.InvalidAssignmentException e)
        {
            exceptionFound = true;
        }
        
        System.assert(exceptionFound, 'The developer must be prevented from assigning from tagged items that have not been inserted into the database.');
    }
    
    static testMethod void testAssignFromList_NullException()
    {
        Boolean exceptionFound = false;
        try
        {
            List<String> types;
            UnitTest.createTestData(grp).many(2).property(SobjectServices.getFullyQualifiedName('Status__c')).assignFrom(types);
        }
        catch(UnitTest.InvalidAssignmentException e)
        {
            exceptionFound = true;
        }
        
        System.assert(exceptionFound, 'The developer must be prevented from passing in null lists to assignFrom');
    }
    
    static testMethod void testAssignFromList_EmptyException()
    {
        Boolean exceptionFound = false;
        try
        {
            UnitTest.createTestData(grp).many(2).property(SobjectServices.getFullyQualifiedName('Status__c')).assignFrom(new List<String>{});
        }
        catch(UnitTest.InvalidAssignmentException e)
        {
            exceptionFound = true;
        }
        
        System.assert(exceptionFound, 'The developer must be prevented from passing in empty lists to assignFrom');
    }
    
    static testMethod void testAssignFromList_WhenContextSizeLessThanSizeOfSpecifiedValueList()
    {
        Set<String> specifiedValues = new Set<String> {'Regular','Role','Case','Lead'};
        UnitTest.createTestData(grp).many(2).property(SobjectServices.getFullyQualifiedName('Status__c')).assignFrom(new List<String>(specifiedValues));
        Set<String> typesEncountered = new Set<String>();
        for(Release__c g : (List<Release__c>) UnitTest.get(Release__c.SObjectType).getList())
        {
            typesEncountered.add(g.Status__c);
        }
        
        System.assert(specifiedValues.containsAll(typesEncountered),'When we assign a property from a list of specified values, the property should only have values found in the list of specified values');
    }
    
    static testMethod void testAssignFrom_ByTag_WhenContextSizeLessThanTaggedObjectsSize()
    {
        UnitTest.createTestData(grp).many(50).tag('Marketing Queues').insertAll();
        UnitTest.createTestData(leads).single().property('OwnerID').assignFrom('Marketing Queues');
        
        ID leadOwner = (ID) UnitTest.get(Project__c.SObjectType).getList()[0].get('OwnerID');
        Set<ID> possibleOwners = Pluck.ids(UnitTest.get(Release__c.SObjectType).getList());
        System.assert(possibleOwners.contains(leadOwner),'We expect the lead to be assigned to one of the marketing queues');
    }
    
    static testMethod void testAssignFrom_ByTag_WhenContextSizeEqualToTaggedObjectsSize()
    {
        final Integer NUM = BULK_NUMBER;
        UnitTest.createTestData(grp).many(NUM).tag('Marketing Queues').insertAll();
        UnitTest.createTestData(leads).many(NUM).property('OwnerID').assignFrom('Marketing Queues');
        
        Set<ID> groupsEncountered = new Set<ID>();
        for(Project__c l : (List<Project__c>) UnitTest.get(Project__c.SObjectType).getList())
        {
            groupsEncountered.add(l.OwnerID);
        }
        
        System.assertEquals(NUM,groupsEncountered.size(),'We expect to assign all the marketing queues between the leads');
        System.assert(groupsEncountered == (Pluck.ids(UnitTest.get(Release__c.SObjectType).getList())),'We expect to assign all the marketing queues between the leads');
    }
    
    static testMethod void testAssignFromList_WhenContextSizeEqualToSizeOfSpecifiedValueList()
    {
        Set<String> specifiedValues = new Set<String> {'Regular','Role','Case','Lead'};
        UnitTest.createTestData(grp).many(specifiedValues.size()).property(SobjectServices.getFullyQualifiedName('Status__c')).assignFrom(new List<String>(specifiedValues));
        Set<String> typesEncountered = new Set<String>();
        for(Release__c g : (List<Release__c>) UnitTest.get(Release__c.SObjectType).getList())
        {
            typesEncountered.add(g.Status__c);
        }
        System.assert(specifiedValues == typesEncountered,'When we assign a property from a list of specified values, the property should only have values found in the list of specified values');
    }
    
    static testMethod void testAssignFromList_WhenContextSizeGreaterThanSizeOfSpecifiedValueList()
    {
        List<String> specifiedValues = new List<String> {'Regular','Role','Case','Lead'};
        UnitTest.createTestData(grp).many(8).property(SobjectServices.getFullyQualifiedName('Status__c')).assignFrom(specifiedValues);
        Map<String, Integer> valueToNumberOfTimesEncountered = new Map<String, Integer>();
        
        for(Release__c g : (List<Release__c>) UnitTest.get(Release__c.SObjectType).getList())
        {
            if(valueToNumberOfTimesEncountered.containsKey(g.Status__c))
            {
                valueToNumberOfTimesEncountered.put(g.Status__c,valueToNumberOfTimesEncountered.get(g.Status__c) + 1);
            }
            else
            {
                valueToNumberOfTimesEncountered.put(g.Status__c,1);
            }
        }
        
        Set<String> typesEncountered = new Set<String>();
        for(String type : valueToNumberOfTimesEncountered.keySet())
        {
            typesEncountered.add(type);
            System.assertEquals(2,valueToNumberOfTimesEncountered.get(type),'We expect to assign each specified value twice');
        }
        
        System.assert(typesEncountered==(new Set<String>(specifiedValues)),'We expect to assign objects to each and every specified value');
    }
    
    static testMethod void testAssignFrom_ByTag_WhenContextSizeGreaterThanTaggedObjectsSize()
    {
        UnitTest.createTestData(grp).many(4).tag('Marketing Queues').insertAll();
        UnitTest.createTestData(leads).many(8).property('OwnerID').assignFrom('Marketing Queues');
        Map<ID, Integer> groupIDToNumberOfTimesEncountered = new Map<ID, Integer>();
        for(Project__c l : (List<Project__c>) UnitTest.get(Project__c.SObjectType).getList())
        {
            if(groupIDToNumberOfTimesEncountered.containsKey(l.OwnerID))
            {
                groupIDToNumberOfTimesEncountered.put(l.OwnerID,groupIDToNumberOfTimesEncountered.get(l.OwnerID) + 1);
            }
            else
            {
                groupIDToNumberOfTimesEncountered.put(l.OwnerID,1);
            }
        }
        
        Set<ID> groupsEncountered = new Set<ID>();
        for(ID groupID : groupIDToNumberOfTimesEncountered.keySet())
        {
            groupsEncountered.add(groupID);
            System.assertEquals(2,groupIDToNumberOfTimesEncountered.get(groupID),'Because there as twice as many leads in the context as there are groups in the specified tag, we will assign each group in the tag twice');
        }
        
        System.assert(groupsEncountered==(Pluck.ids(UnitTest.get(Release__c.SObjectType).getList())),'We expect to assign all of the tagged groups between all the lead');
    }
    
    static testMethod void testForEach_InvalidTag()
    {
        Boolean exceptionFound = false;
        try
        {
            UnitTest.forEach('Invalid Tag Because It Has Not Been Assigned To Any Objects');  
        }
        catch(UnitTest.InvalidTagException e)
        {
            exceptionFound = true;
        }
        System.assert(exceptionFound,'We must prevent the developer from using invalid tags');
    }
    
    static testMethod void testDummyInsertFailure_MultipleObjects()
    {
        UnitTest.createTestData(acct).many(10);
        UnitTest.createTestData(leads).many(10);
        
        Boolean exceptionFound = false;
        try
        {
            UnitTest.allData().dummyInsert();
        }
        catch(UnitTest.DatabaseOperationException e)
        {
            exceptionFound = true;  
        }
        System.assert(exceptionFound,'As a best practice, we must prevent the developer from dummy inserting multiple types of objects at the same time');
    }
    
    static testMethod void testDummyInsertFailure_NonNullIDs()
    {
        UnitTest.createTestData(grp).many(10).insertAll();
        
        Boolean exceptionFound = false;
        try
        {
            UnitTest.get(Release__c.SObjectType).dummyInsert();
        }
        catch(UnitTest.DatabaseOperationException e)
        {
            exceptionFound = true;  
        }
        System.assert(exceptionFound,'We cannot dummy insert objects that already have their ID fields populated');
    }
    
    static testMethod void testDummyInsert()
    {
        final Integer NUM = BULK_NUMBER;
        UnitTest.createTestData(acct).many(NUM).dummyInsert();
        UnitTest.createTestData(acct).many(NUM).dummyInsert();
        Set<ID> acctIDs = Pluck.ids(UnitTest.get(Backlog__c.SObjectType).getList());
        System.assertEquals(NUM*2, acctIDs.size(), 'We expect to get back 20 unique IDs');
        for(ID acctID : acctIds)
        {
            System.assertEquals(Backlog__c.SObjectType, acctID.getSObjectType(), 'We expect to get back a valid account ID');
        }
    }
    
    static testMethod void testForEach_AfterFinalizingTestData()
    {
        UnitTest.createTestData(acct).many(10).tag('Accounts');
        UnitTest.createTestData(grp).many(10).tag('Groups Analyzed Before Test Data Initalized');
        UnitTest.analyze('Groups Analyzed Before Test Data Initalized');
        
        Boolean exceptionFound = false;
        try
        {
            UnitTest.forEach('Accounts');
        }
        catch(UnitTest.TestDataFinalizedException e)
        {
            exceptionFound = true;
        }
        System.assert(exceptionFound, 'The developer cannot call foreach after calling analyze functions');
    }
    
    static testMethod void testDummyInsert_AfterFinalizingTestData()
    {
        UnitTest.createTestData(acct).many(10).tag('Accounts');
        UnitTest.createTestData(grp).many(10).tag('Groups Analyzed Before Test Data Initalized');
        UnitTest.analyze('Groups Analyzed Before Test Data Initalized');
        
        Boolean exceptionFound = false;
        try
        {
            UnitTest.get('Accounts').dummyInsert();
        }
        catch(UnitTest.TestDataFinalizedException e)
        {
            exceptionFound = true;
        }
        System.assert(exceptionFound, 'The developer cannot call dummyInsert after calling analyze functions');
    }
    
    static testMethod void testTag_AfterFinalizingTestData()
    {
        UnitTest.createTestData(grp).many(10).tag('Groups');
        UnitTest.createTestData(grp).many(10).tag('Groups Analyzed Before Test Data Initalized');
        UnitTest.analyze('Groups Analyzed Before Test Data Initalized');
        
        Boolean exceptionFound = false;
        try
        {
            UnitTest.get(Release__c.SObjectType).tag('Tag');
        }
        catch(UnitTest.TestDataFinalizedException e)
        {
            exceptionFound = true;
        }
        System.assert(exceptionFound, 'The developer cannot call tag after calling analyze functions');
    }
    
    static testMethod void testDivide_AfterFinalizingTestData()
    {
        UnitTest.createTestData(grp).many(10).tag('Groups');
        UnitTest.createTestData(grp).many(10).tag('Groups Analyzed Before Test Data Initalized');
        UnitTest.analyze('Groups Analyzed Before Test Data Initalized');
        
        Boolean exceptionFound = false;
        try
        {
            UnitTest.get(Release__c.SObjectType).divide(2);
        }
        catch(UnitTest.TestDataFinalizedException e)
        {
            exceptionFound = true;
        }
        System.assert(exceptionFound, 'The developer cannot call divide after calling analyze functions');
    }
    
    static testMethod void testInsert_AfterFinalizingTestData()
    {
        UnitTest.createTestData(grp).many(10).tag('Groups');
        UnitTest.createTestData(grp).many(10).tag('Groups Analyzed Before Test Data Initalized');
        UnitTest.analyze('Groups Analyzed Before Test Data Initalized');
        
        Boolean exceptionFound = false;
        try
        {
            UnitTest.get(Release__c.SObjectType).insertAll();
        }
        catch(UnitTest.TestDataFinalizedException e)
        {
            exceptionFound = true;
        }
        System.assert(exceptionFound, 'The developer cannot call insertAll after calling analyze functions');
    }
    
     static testMethod void testCreateTestData_AfterFinalizingTestData()
    {
        UnitTest.createTestData(grp).many(10).tag('Groups Analyzed Before Test Data Initalized');
        UnitTest.analyze('Groups Analyzed Before Test Data Initalized');
        
        Boolean exceptionFound = false;
        try
        {
            UnitTest.createTestData(acct);
        }
        catch(UnitTest.TestDataFinalizedException e)
        {
            exceptionFound = true;
        }
        System.assert(exceptionFound, 'The developer cannot call createTestData after calling analyze functions');
    }
    
    static testMethod void testAddData_AfterFinalizingTestData()
    {
        UnitTest.createTestData(grp).many(10).tag('Groups Analyzed Before Test Data Initalized');
        UnitTest.analyze('Groups Analyzed Before Test Data Initalized');
        
        Boolean exceptionFound = false;
        try
        {
            UnitTest.addData([Select ID From User Limit 2]);
        }
        catch(UnitTest.TestDataFinalizedException e)
        {
            exceptionFound = true;
        }
        System.assert(exceptionFound, 'The developer cannot call addData after calling analyze functions');
    }
    
    static testMethod void testProperty_AfterFinalizingTestData()
    {
        UnitTest.addData([Select ID From User Where IsActive=True Limit 2]);
        UnitTest.createTestData(grp).many(10).tag('Groups Analyzed Before Test Data Initalized');
        UnitTest.analyze('Groups Analyzed Before Test Data Initalized');
        Boolean exceptionFound = false;
        try
        {
            UnitTest.get(User.SObjectType).property('ProfileID');
        }
        catch(UnitTest.TestDataFinalizedException e)
        {
            exceptionFound = true;
        }
        System.assert(exceptionFound, 'The developer cannot modify the property after calling analyze functions');
    }
    
    static testMethod void testAssign_AfterFinalizingTestData()
    {
        UnitTest.addData([Select ID From User Where IsActive=True Limit 2]);
        UnitTest.createTestData(grp).many(10).tag('Groups Analyzed Before Test Data Initalized');
        UnitTest.analyze('Groups Analyzed Before Test Data Initalized');
        Boolean exceptionFound = false;
        try
        {
            UnitTest.get(User.SObjectType).assign('ProfileID',null);
        }
        catch(UnitTest.TestDataFinalizedException e)
        {
            exceptionFound = true;
        }
        System.assert(exceptionFound, 'The developer cannot call assign after calling analyze functions');
    }
    
    static testMethod void testAnalyze_InvalidTag()
    {
        Boolean exceptionFound = false;
        UnitTest.createTestData(grp).many(10).tag('Test Groups').insertAll();
        
        try
        {
            UnitTest.analyze('Test Gps');
        }
        catch(UnitTest.InvalidTagException e)
        {
            exceptionFound = true; 
        }
        System.assert(exceptionFound, 'The developer cannot analyze tags that do not exist');
    }
    
    static testMethod void testhasID()
    {
        UnitTest.createTestData(acct).many(BULK_NUMBER*10).tag('Accounts').dummyInsert();
        Set<ID> validIDs = Pluck.ids(UnitTest.get(Backlog__c.SObjectType).getList());
        
        
        
        for(ID validID : validIDs)  
        {
            System.assert(UnitTest.analyze('Accounts').hasID(validID),'We should be able to identify when a certain ID belongs to the context');
        }
        
        ID invalidID = UserInfo.getUserId();
        
        System.assert(!UnitTest.analyze('Accounts').hasID(invalidID),'We should be able to identify when a certain ID does not belong to the context');
    }
    
    static testMethod void testIncludesID_NullIDContext()
    {
        UnitTest.createTestData(acct).many(5).tag('Accounts');
        
        
        Boolean exceptionFound = false;
        try
        {
            UnitTest.analyze('Accounts').hasID('001i000000R7Y98');
        }
        catch(UnitTest.AnalyzeException a)
        {
            exceptionFound = true;
        }
        
        System.assert(exceptionFound, 'The developer cannot perform analysis functions on objects without a tag');
    }
    
    static testMethod void testForEachCreate_BadSpecification()
    {
        UnitTest.createTestData(acct).many(2).tag('Accounts').dummyInsert();
        Boolean exceptionFound = false;
        try
        { 
            UnitTest.forEach('Accounts').create(1,opportunities).copyProperty('ID=>'+SObjectServices.getFullyQualifiedName('Release__c'));
        }
        catch(UnitTest.IllegalSpecificationsException e)
        {
            exceptionFound = true;
        }
        System.assert(exceptionFound,'We expect to get an exception when the specifications for copyProperty are not correctly defined');
        
    }
    static testMethod void testForEachCreate()
    {
        final Integer accountsPerCategory = BULK_NUMBER;
        final Integer categories = 3;
        
        UnitTest.createTestData(acct).many(accountsPerCategory*categories).divide(categories)
                                                                             .part('Account With Five Opportunities')
                                                                             .part('Account With One Opportunity')
                                                                             .part('Account Without Opportunities');                                                                     
        UnitTest.get(Backlog__c.SObjectType).dummyInsert();
                                                            
        UnitTest.forEach('Account With Five Opportunities').create(5,opportunities).copyProperty('ID->'+SObjectServices.getFullyQualifiedName('Release__c')).tag('Opportunities For Accounts With Five Opportunities');
        UnitTest.forEach('Account With One Opportunity').create(1,opportunities).copyProperty('ID->'+SObjectServices.getFullyQualifiedName('Release__c'));
        UnitTest.get(Deployment_Attempt__c.SObjectType).dummyInsert();
        
        
        List<Deployment_Attempt__c> allOpptys = UnitTest.get(Deployment_Attempt__c.SObjectType).getList();
        
        final Integer EXPECTED_NUM_OPPORTUNITIES  = accountsPerCategory*5+accountsPerCategory;
        System.assertEquals(EXPECTED_NUM_OPPORTUNITIES,allOpptys.size(),'We expect to create the right number of opportunities');
        
        Map<ID,List<Deployment_Attempt__c>> accountIDToOpportunity = GroupBy.ids(SObjectServices.getFullyQualifiedName('Release__c'), allOpptys);
        for(ID acctID : accountIDToOpportunity.keySet())
        {
            if(UnitTest.analyze('Account With Five Opportunities').hasID(acctID))
            {
                System.assertEquals(5,accountIDToOpportunity.get(acctID).size(),'We expect to create as many opportunities for account as specified');
                for(Deployment_Attempt__c o : accountIDToOpportunity.get(acctID))
                {
                    System.assert(UnitTest.analyze('Opportunities For Accounts With Five Opportunities').hasID(o.ID),'We expect to include only the correct opportunities');
                }
            }
            else if(UnitTest.analyze('Account With One Opportunity').hasID(acctID))
            {
                System.assertEquals(1,accountIDToOpportunity.get(acctID).size(),'We expect to create as many opportunities for account as specified');
                Deployment_Attempt__c o = accountIDToOpportunity.get(acctID)[0];
                System.assert(!UnitTest.analyze('Opportunities For Accounts With Five Opportunities').hasID(o.ID),'We expect to include only the correct opportunities');
            }
            else
            {
                System.assert(false,'We do not expect to create any opportunities for accounts that we have not called forEach on');
            }
        }
    }
    
    static testMethod void testAssignCustomAttributeError_WhenAttributeNotInitalized()
    {
        Boolean exceptionFound = false;
        try
        {
            UnitTest.createTestData(opportunities).many(10).assign('*Expected Owner*',UserInfo.getUserID());
        }
        catch(UnitTest.CustomAttributeException e){
            exceptionFound = true;
        }
        System.assert(exceptionFound, 'We expect to get an exception when we attempt to assign into a custom attribute that is not yet initalized');
    }
    
    static testMethod void testPropertyCustomAttributeError_WhenAttributeNotInitalized()
    {
        Boolean exceptionFound = false;
        try
        {
            UnitTest.addData([Select ID From User Where IsActive=True Limit 5]).tag('Users');
            UnitTest.createTestData(opportunities).many(10).property('*Expected Owner*').assignFrom('Users');
        }
        catch(UnitTest.CustomAttributeException e){
            exceptionFound = true;
        }
        System.assert(exceptionFound, 'We expect to get an exception when we attempt to assign into a custom attribute that is not yet initalized');
    }
    static testMethod void testForEachCustomAttributeError_WhenSourceAttributeNotInitalized()
    {
        Boolean exceptionFound = false;
        try
        {
            UnitTest.createTestData(acct).many(10).tag('Accounts').dummyInsert();
            UnitTest.forEach('Accounts').create(10,opportunities).copyProperty('*Custom Attribute*->OwnerID');
        }
        catch(UnitTest.CustomAttributeException e){
            exceptionFound = true;
        }
        System.assert(exceptionFound, 'We expect to get an exception when we attempt to assign into a custom attribute that is not yet initalized');
    }
     static testMethod void testExtractPropertyValuesError_WhenSpecificationsNotCorrectlyFormatted()
    {
        UnitTest.createTestData(acct).many(10).tag('Accounts').assign(SObjectServices.getFullyQualifiedName('Summary__c'),'A').dummyInsert();
        Boolean exceptionFound = false;
        try
        {
            UnitTest.get('Accounts').extractPropertyValues('ID=>'+SObjectServices.getFullyQualifiedName('Summary__c'));
        }
        catch(UnitTest.IllegalSpecificationsException a)
        {
            exceptionFound = true;
        }
        System.assert(exceptionFound, 'We expect to get an exception when the specification string is not correctly formatted');
    }
    static testMethod void testExtractMapError_WhenSpecificationsNotCorrectlyFormatted()
    {
        UnitTest.createTestData(acct).many(10).tag('Accounts').assign(SObjectServices.getFullyQualifiedName('Summary__c'),'A').dummyInsert();
        Boolean exceptionFound = false;
        try
        {
            UnitTest.get('Accounts').extractMap('ID=>Name');
        }
        catch(UnitTest.IllegalSpecificationsException a)
        {
            exceptionFound = true;
        }
        System.assert(exceptionFound, 'We expect to get an exception when the specification string is not correctly formatted');
    }
    static testMethod void testNewProperty_InvalidPropertyName()
    {
        testInvalidAttributeName('*Expected Owner');
        testInvalidAttributeName('Expected Owner*');
        testInvalidAttributeName('Expected Owner');
    }
    static void testInvalidAttributeName(String invalidAttribute)
    {
        Boolean exceptionFound = false;
        try
        {
            UnitTest.createTestData(acct).many(BULK_NUMBER).newAttribute(invalidAttribute);
        }
        catch(UnitTest.CustomAttributeException e)
        {
            exceptionFound = true;
        }
        System.assert(exceptionFound, 'Only attribute names that begin and end with an asterisk are valid attribute names. The following attribute should have been detected as invalid: ' + invalidAttribute);
    }
    
    static testMethod void testGetTags()
    {
        final String TAG_0 = 'base';
        final String TAG_1 = 'Multiple Words ';
        final String TAG_2 = 'tag2';
        final String TAG_3 = 'tag3';
        final String TAG_4 = '4';
        UnitTest.createTestData(acct).many(BULK_NUMBER).tag(TAG_0).divide(2).part(TAG_1).part(TAG_2);
        UnitTest.get(TAG_2).divide(2).part(TAG_3).part(TAG_4);
        UnitTest.get(Backlog__c.SObjectType).dummyInsert();
        
        final String TAG_1_RETURNED = 'multiple words';
        for(Backlog__c a : (List<Backlog__c>) UnitTest.get(Backlog__c.SObjectType).getList())
        {
            if(UnitTest.analyze(TAG_1).hasID(a.ID))
            {
                System.assertEquals(new Set<String>{TAG_0,TAG_1_RETURNED}, UnitTest.analyze(TAG_0).selectByID(a.ID).getTags(), 'By using the getTags functions, the developer must be able to identify all the list of tags an element is associated with');
            }
            else if(UnitTest.analyze(TAG_3).hasID(a.ID))
            {
                System.assertEquals(new Set<String>{TAG_0,TAG_2,TAG_3}, UnitTest.analyze(TAG_0).selectByID(a.ID).getTags(), 'By using the getTags functions, the developer must be able to identify all the list of tags an element is associated with');
            }
            else if(UnitTest.analyze(TAG_4).hasID(a.ID))
            {
                System.assertEquals(new Set<String>{TAG_0,TAG_2,TAG_4}, UnitTest.analyze(TAG_0).selectByID(a.ID).getTags(), 'By using the getTags functions, the developer must be able to identify all the list of tags an element is associated with');
            }
            else
            {
                System.assert(false, 'Tagging must correctly work');
            }
        }
    }
    
    static testMethod void testSelectByID_WhenNullID()
    {
        Boolean exceptionFound = false;
        UnitTest.createTestData(acct).many(BULK_NUMBER).tag('Accounts').assign(SObjectServices.getFullyQualifiedName('Summary__c'),'A');
        
        try
        {
            UnitTest.analyze('Accounts').selectByID('001i000000R7Y98');
        }
        catch(UnitTest.AnalyzeException a)
        {
            exceptionFound = true; 
        }
        System.assert(exceptionFound, 'We cannot use analyze functions on test data that has null ID values');
    }
    
    static testMethod void testSelectByID_WhenIDDoesNotExist()
    {
        Boolean exceptionFound = false;
        UnitTest.createTestData(acct).many(BULK_NUMBER).tag('Accounts').dummyInsert();
        
        try
        {
            UnitTest.analyze('Accounts').selectByID('003i000000R7Y98');
        }
        catch(UnitTest.AnalyzeException a)
        {
            exceptionFound = true; 
        }
        System.assert(exceptionFound, 'We cannot call selectByID with an ID that does not exist');
    }
    
    static testMethod void testTraverseWhenAttributeNotIDValue()
    {
        UnitTest.createTestData(acct).many(10).tag('Accounts').dummyInsert();
        UnitTest.forEach('Accounts').create(1,opportunities).copyProperty('ID->'+SObjectServices.getFullyQualifiedName('Release__c')).tag('Opptys');
        UnitTest.get('Opptys').assign(SObjectServices.getFullyQualifiedName('UUID__c'),'Opportunity Name').dummyInsert();
        ID sampleOppID = UnitTest.get('Opptys').getList()[0].ID;
        
        
        
        Boolean exceptionFound = false;
        try
        {
            UnitTest.analyze('Opptys').selectByID(sampleOppID).traverse(SObjectServices.getFullyQualifiedName('UUID__c'));    
        } 
        catch(UnitTest.AnalyzeException e)
        {
            exceptionFound = true;
        }
        System.assert(exceptionFound,'The developer should not be able to traverse by a property that is not an ID value');
    }
    
    static testMethod void testTraverseWhenIDNotInTestData()
    {
        UnitTest.createTestData(acct).many(10).tag('Accounts').dummyInsert();
        UnitTest.forEach('Accounts').create(1,opportunities).tag('Opptys');
        UnitTest.get('Opptys').newAttribute('*Relevant Contact ID*').assign('003i000000NDLdo').dummyInsert();
        ID sampleOppID = UnitTest.get('Opptys').getList()[0].ID;
        
        
        
        Boolean exceptionFound = false;
        try
        {
            UnitTest.analyze('Opptys').selectByID(sampleOppID).traverse('*Relevant Contact ID*');   
        } 
        catch(UnitTest.AnalyzeException e)
        {
            exceptionFound = true;
        }
        System.assert(exceptionFound,'The developer should not be able to traverse by an ID that does not exist in test data');
    }
    
    static testMethod void testDataItemAnalysisFunctions()
    {
        List<String> sampleNames = new List<String> {'Name One','Name Two'};
        UnitTest.createTestData(acct).many(BULK_NUMBER).tag('Accounts').property(SObjectServices.getFullyQualifiedName('Summary__c')).assignFrom(sampleNames).dummyInsert();
        UnitTest.forEach('Accounts').create(1,opportunities).copyProperty('ID->'+SObjectServices.getFullyQualifiedName('Release__c')).copyProperty('ID->*Account ID Clone*').tag('Opptys');
        UnitTest.get('Opptys').dummyInsert();
        
        
        Map<ID, Object> expectedMapIDToAccountID = new Map<ID, Object>();
        for(Deployment_Attempt__c o : (List<Deployment_Attempt__c>) UnitTest.get('Opptys').getList())
        {
            expectedMapIDToAccountID.put(o.ID,o.Release__c); 
        }
        
        Map<ID, String> expectedMapAccountIDToName = new Map<ID, String>();
        for(Backlog__c a : (List<Backlog__c>) UnitTest.get('Accounts').getList())
        {
            expectedMapAccountIDToName.put(a.ID,a.Summary__c); 
        }
        
        for(ID id : expectedMapIDToAccountID.keySet())
        {
            ID expectedAccount = (ID) expectedMapIDToAccountID.get(id);
            System.assertEquals(expectedAccount,UnitTest.analyze('Opptys').selectByID(id).getSObject().get(SObjectServices.getFullyQualifiedName('Release__c')),'The Select By ID function should lead us to the right test datum');
            System.assertEquals(expectedAccount,UnitTest.analyze('Opptys').selectByID(id).getPropertyValue(SObjectServices.getFullyQualifiedName('Release__c')),'The getPropertyValue function should return the right value');
            System.assertEquals(expectedAccount,UnitTest.analyze('Opptys').selectByID(id).getPropertyValue('*Account ID Clone*'),'The getPropertyValue function should return the right value for custom attributes');
            String expectNameOfAccount = expectedMapAccountIDToName.get(expectedAccount);
            System.assertEquals(expectNameOfAccount,UnitTest.analyze('Opptys').selectByID(id).traverse(SObjectServices.getFullyQualifiedName('Release__c')).getPropertyValue(SObjectServices.getFullyQualifiedName('Summary__c')), 'The traverse function should find the test datum with the ID matching the value found in the specified property');
        }
    }
    
    static testMethod void testExtractMapIDTo_WhenNullID()
    {
        Boolean exceptionFound = false;
        UnitTest.createTestData(acct).many(10).tag('Accounts').assign(SObjectServices.getFullyQualifiedName('Summary__c'),'A');
        
        try
        {
            UnitTest.analyze('Accounts').extractMapIDTo(SObjectServices.getFullyQualifiedName('Summary__c'));
        }
        catch(UnitTest.AnalyzeException a)
        {
            exceptionFound = true;
        }
        System.assert(exceptionFound, 'We cannot use analyze functions on test data that has null ID values');
    }
    
    static testMethod void testExtractMapIDTo()
    {
        Boolean exceptionFound = false;
        UnitTest.createTestData(acct).many(BULK_NUMBER).tag('Accounts').dummyInsert();
        UnitTest.forEach('Accounts').create(1,opportunities).copyProperty('ID->'+SObjectServices.getFullyQualifiedName('Release__c')).tag('Opptys');
        UnitTest.get('Opptys').dummyInsert();
        
        Map<ID, Object> mapIDToAccountID = UnitTest.analyze('Opptys').extractMapIDTo(SObjectServices.getFullyQualifiedName('Release__c'));
        Map<ID, Object> expectedMapIDToAccountID = new Map<ID, Object>();
        for(Deployment_Attempt__c o : (List<Deployment_Attempt__c>) UnitTest.get('Opptys').getList())
        {
            expectedMapIDToAccountID.put(o.ID,o.Release__c); 
        }
        System.assert(mapIDToAccountID.keySet()==expectedMapIDToAccountID.keySet(), 'The Extract Map ID To Function must correctly populate the key values of the map');
        for(ID opptyId : mapIDToAccountID.keySet())
        {
            System.assertEquals(expectedMapIDToAccountID.get(opptyID),mapIDToAccountID.get(opptyID), 'The Extract Map ID To Function must correctly populate the right value for each key');
        }
    }
    
    static testMethod void testExtractMapIDTo_CustomAttribute()
    {
        UnitTest.createTestData(acct).many(BULK_NUMBER).tag('Accounts').dummyInsert();
        UnitTest.forEach('Accounts').create(1,opportunities).copyProperty('ID->'+SObjectServices.getFullyQualifiedName('Release__c')).copyProperty('ID->*Original Amount*').tag('Opptys');
        UnitTest.get('Opptys').newAttribute('*Original Amount Clone*').copyFromProperty('*Original Amount*');
        UnitTest.get('Opptys').dummyInsert();
        
        Map<ID, Object> mapIDToAccountID = UnitTest.analyze('Opptys').extractMapIDTo('*Original Amount Clone*');
        Map<ID, Object> expectedMapIDToAccountID = new Map<ID, Object>();
        for(Deployment_Attempt__c o : (List<Deployment_Attempt__c>) UnitTest.get('Opptys').getList())
        {
            expectedMapIDToAccountID.put(o.ID,o.Release__c); 
        }
        System.assert(mapIDToAccountID.keySet()==expectedMapIDToAccountID.keySet(), 'The Extract Map ID To Function must correctly populate the key values of the map');
        for(ID opptyId : mapIDToAccountID.keySet())
        {
            System.assertEquals(expectedMapIDToAccountID.get(opptyID),mapIDToAccountID.get(opptyID), 'The Extract Map ID To Function must correctly populate the right value for each key');
        }
    }
    
    static testMethod void testExtractMap()
    {
        UnitTest.createTestData(acct).many(BULK_NUMBER).tag('Accounts').dummyInsert();
        UnitTest.forEach('Accounts').create(1,opportunities).copyProperty('ID->'+SObjectServices.getFullyQualifiedName('Release__c')).copyProperty('ID->*Original Amount*').tag('Opptys');
        UnitTest.get('Opptys').newAttribute('*Original Amount Clone*').copyFromProperty('*Original Amount*');
        UnitTest.get('Opptys').dummyInsert();
        Map<Object, Object> mapIDToAccountID =  UnitTest.get('Opptys').extractMap('ID->*Original Amount Clone*');
        Map<ID, Object> expectedMapIDToAccountID = new Map<ID, Object>();
        for(Deployment_Attempt__c o : (List<Deployment_Attempt__c>) UnitTest.get('Opptys').getList())
        {
            expectedMapIDToAccountID.put(o.ID,o.Release__c); 
        }
        Set<ID> mapIDToAccountIDKeySet = new Set<ID>();
        for(Object id : mapIDToAccountID.keySet())
        {
            mapIDToAccountIDKeySet.add((ID) id);
        }
        
        System.assert(mapIDToAccountIDKeySet==expectedMapIDToAccountID.keySet(), 'The Extract Map Function must correctly populate the key values of the map');
        for(ID opptyId : expectedMapIDToAccountID.keySet())
        {
            System.assertEquals(expectedMapIDToAccountID.get(opptyID),mapIDToAccountID.get(opptyID), 'The Extract Map ID To Function must correctly populate the right value for each key');
        } 
    }
    
    static testMethod void testExtractMap_WhenMultipleNonUniqueValues()
    {
        UnitTest.createTestData(acct).many(BULK_NUMBER).tag('Accounts')
                                     .assign(SObjectServices.getFullyQualifiedName('Summary__c'),'Charlie').assign(SObjectServices.getFullyQualifiedName('User_Goal__c'),'1234567890')
                                     .dummyInsert();
                                     
        Map<Object, Object> nameToPhone = UnitTest.get('Accounts').extractMap(SObjectServices.getFullyQualifiedName('Summary__c')+'->'+SObjectServices.getFullyQualifiedName('User_Goal__c'));
        
        System.assertEquals(1,nameToPhone.size(),'There is only one unique pair of name to phone number');
        System.assertEquals('1234567890',nameToPhone.get('Charlie'),'We expect to capture the correct mapping from key to value pair');
    }   
    
    static testMethod void testExtractMap_WhenMultipleUniqueValues()
    {
        UnitTest.createTestData(acct).many(10).tag('Accounts').assign(SObjectServices.getFullyQualifiedName('Summary__c'),'Charlie').dummyInsert();
        Boolean exceptionFound = false;
        try
        {
            UnitTest.get('Accounts').extractMap(SObjectServices.getFullyQualifiedName('Summary__c')+'->ID');
        }
        catch(UnitTest.IllegalSpecificationsException e)
        { 
            exceptionFound = true;
        }
        System.assert(exceptionFound,'We cannot extractMap with specifications that would cause there to be more than one value for a key');
    }
    
    static testMethod void testNewPropertyDoesNotOverwrite()
    {
        final String groupOneName = 'GP123';
        UnitTest.createTestData(grp).many(BULK_NUMBER).divide(2).part('Groups One').part('Groups Two');
        UnitTest.get('Groups One').newAttribute('*Expected Name*').assign(groupOneName);
        UnitTest.get(Release__c.SObjectType).newAttribute('*Expected Name*');
        UnitTest.get(Release__c.SObjectType).dummyInsert();
        
        Map<ID, Object> groupsOneToExpectedName = UnitTest.analyze('Groups One').extractMapIDTo('*Expected Name*');
        for(ID id : groupsOneToExpectedName.keySet())
        {
            System.assertEquals(groupOneName,groupsOneToExpectedName.get(id),'We expect to maintain property values for all test data where the attribute is already initialized when we use newAttribute.');
        }
    }
    
    static testMethod void testAssertSetEquals_SetNotEquivalent()
    {
        UnitTest.createTestData(acct).many(50).dummyInsert();
        UnitTest.createTestData(grp).many(50).dummyInsert();
        Set<ID> actualIds = Pluck.ids('ID',UnitTest.get(Backlog__c.SObjectType).getList());
        Set<Object> expectedIds = new Set<Object>();
        for(ID id : Pluck.ids(UnitTest.get(Release__c.SObjectType).getList()))
        {
            expectedIds.add(id);
        }
        
        Boolean exceptionFound = false;
        try
        {
            UnitTest.assertSetEquals(expectedIds,actualIds,'');
        }
        catch(UnitTest.AssertionException e)
        {
            exceptionFound = true;
        }
        
        System.assert(exceptionFound,'The assertion should have failed because the sets are not equivalent');
    }
    
    static testMethod void testAssertSetEquals()
    {
        UnitTest.createTestData(acct).many(50).dummyInsert();
        Set<ID> actualIds = Pluck.ids('ID',UnitTest.get(Backlog__c.SObjectType).getList());
        Set<Object> expectedIds = new Set<Object>();
        for(ID id : actualIds)
        {
            expectedIds.add(id);
        }
        
        try
        {
            UnitTest.assertSetEquals(expectedIds,actualIds,'');
        }
        catch(Exception e)
        {
            System.assert(false,'The assertion should pass but instead we got the exception ' + e);
        }
    }
    
    static testMethod void testAssertSet_SizeAssertion()
    {
        UnitTest.createTestData(acct).many(50).dummyInsert();
        Set<ID> actualIds = Pluck.ids('ID',UnitTest.get(Backlog__c.SObjectType).getList());
        
        Set<Object> expectedIds = new Set<Object>();
        ID idToRemove;
        for(ID id : actualIds)
        {
            expectedIds.add(id);
            idToRemove = id;
        }
        expectedIds.remove(idToRemove);
        
        Boolean exceptionFound = false;
        try
        {
            UnitTest.assertSetEquals(expectedIds,actualIds,'');
        }
        catch(Exception e)
        {
            exceptionFound = true;
        }
        System.assert(exceptionFound, 'We expect our assertion to fail when the sizes do not match up');
    }
    
    static testMethod void testAssertSet_NullActuals()
    {
        UnitTest.createTestData(acct).many(2).dummyInsert();
        Set<ID> actualIds = null;
        Set<Object> expectedIds = new Set<Object> {UnitTest.get(Backlog__c.SObjectType).getList()[0].ID};
        
        Boolean exceptionFound = false;
        try
        {
            UnitTest.assertSetEquals(expectedIds,actualIds,'');
        }
        catch(UnitTest.AnalyzeException e)
        {
            exceptionFound = true;
        }
        System.assert(exceptionFound, 'We expect to get an exception when one of the compared sets is null');
    }
    
    static testMethod void testAssertSet_NullExpected()
    {
        UnitTest.createTestData(acct).many(50).dummyInsert();
        Set<ID> actualIds = Pluck.ids('ID',UnitTest.get(Backlog__c.SObjectType).getList());
        Set<Object> expectedIds = null;
        
        Boolean exceptionFound = false;
        try
        {
            UnitTest.assertSetEquals(expectedIds,actualIds,'');
        }
        catch(UnitTest.AnalyzeException e)
        {
            exceptionFound = true;
        }
        System.assert(exceptionFound, 'We expect to get an exception when one of the compared sets is null');
    }
    
    static testMethod void testExtractPropertyValues()
    {
        final Integer accountsPerCategory = BULK_NUMBER;
        final Integer categories = 3;
        
        UnitTest.createTestData(acct).many(accountsPerCategory*categories).divide(categories)
                                                                             .part('Account With Five Opportunities')
                                                                             .part('Account With One Opportunity')
                                                                             .part('Account Without Opportunities');                                                                     
        UnitTest.get(Backlog__c.SObjectType).dummyInsert();
                                                            
        UnitTest.forEach('Account With Five Opportunities').create(5,opportunities).copyProperty('ID->'+SObjectServices.getFullyQualifiedName('Release__c')).copyProperty('ID->*AccountID Clone*');
        UnitTest.forEach('Account With One Opportunity').create(1,opportunities).copyProperty('ID->'+SObjectServices.getFullyQualifiedName('Release__c')).copyProperty('ID->*AccountID Clone*');
        
        UnitTest.get(Deployment_Attempt__c.SObjectType).dummyInsert();
        
        List<Deployment_Attempt__c> allOpptys = UnitTest.get(Deployment_Attempt__c.SObjectType).getList();
        
        Map<ID,List<Deployment_Attempt__c>> accountIDToOpportunity = GroupBy.ids(SObjectServices.getFullyQualifiedName('Release__c'), allOpptys);
        Map<ID, Set<ID>> testAccountIDToOpportunityID = new Map<ID, Set<ID>>();
        for(ID acctID : accountIDToOpportunity.keySet())
        {
            Set<ID> opptyIDs = new Set<ID>();
            for(Deployment_Attempt__c o : accountIDToOpportunity.get(acctID))
            {
                opptyIDs.add(o.ID);
            }
            testAccountIDToOpportunityID.put(acctID,opptyIDs);
        }
        
        Map<Object, Set<Object>> accountIDToOpportunityID = UnitTest.get(Deployment_Attempt__c.SObjectType).extractPropertyValues(SObjectServices.getFullyQualifiedName('Release__c')+'->ID');
        Map<Object, Set<Object>> clonedAccountIDToOpportunityID = UnitTest.get(Deployment_Attempt__c.SObjectType).extractPropertyValues('*AccountID Clone*->ID');
     
        for(ID acctID : accountIDToOpportunity.keySet())
        {
             UnitTest.assertSetEquals(accountIDToOpportunityID.get(acctID),testAccountIDToOpportunityID.get(acctID),'We expect to get all the ID properties grouped correctly by the AccountID property');
             UnitTest.assertSetEquals(clonedAccountIDToOpportunityID.get(acctID),testAccountIDToOpportunityID.get(acctID),'We expect to get all the ID properties grouped correctly by the cloned AccountID custom attribute');
        }   
    }

    static testMethod void testBranch_SpecificationsError_OnlyOneTagSpecified()
    {
        assertBranchSpecificationsError('red accounts','When the user only puts in one tag, there should be an error');
    }

    static testMethod void testBranch_SpecificationsError_OnlyOneTagSpecifiedButInvalid()
    {
        assertBranchSpecificationsError('red accounts|','When the user only puts in one tag, there should be an error');
    }

    static testMethod void testBranch_SpecificationsError_BlankTagInMiddle()
    {
        assertBranchSpecificationsError('red accounts||blue account','When the user does not use the delimmiter correctly, there should be an error');
    }

    static testMethod void testBranch_SpecificationsError_BlankTags()
    {
        assertBranchSpecificationsError('','When the user puts in an empty string, there should be an error');
    }

    static testMethod void testBranch_SpecificationsError_Null()
    {
        assertBranchSpecificationsError('','When the user puts in a null string, there should be an error');
    }

    static void assertBranchSpecificationsError(String branchParams, String message)
    {
        UnitTest.createTestData(acct).many(10).tag('Accounts');

        Boolean exceptionFound = false;

        try {
            UnitTest.get('Accounts').branch(branchParams);
        }
        catch(UnitTest.IllegalSpecificationsException e) {
            exceptionFound = true;
        }
        catch(Exception e) { }
        
        System.assert(exceptionFound,message);
    }

    static testMethod void testBranchErrorWhenTagExistsAlready()
    {
        UnitTest.createTestData(acct).many(10).tag('Accounts').divide(2).part('New Accounts').part('Old Accounts');
        Boolean exceptionFound = false;
        try{
            UnitTest.get('Accounts').branch('New Accounts|Green Accounts');
         }
        catch(UnitTest.BranchException e)
        {
             exceptionFound = true;
        }
        catch(Exception e) {}

        System.assert(exceptionFound,'When you are trying to branch data and you re-use a tag already present in the data, there must be an error');
    }

    static testMethod void testBranchErrorWhenNotEnoughRecords()
    {
        UnitTest.createTestData(acct).many(4).tag('Accounts').branch('Telecommunications|Industry|Electronics');

        Boolean exceptionFound = false;

        try{
            UnitTest.get('Accounts').branch('New Accounts|Old Accounts');
        }
        catch(UnitTest.BranchException e)
        {
             exceptionFound = true;
        }
        catch(Exception e) {}

        System.assert(exceptionFound,'When there are simply not enough unique groupings to divide as requested, there must be an error');
    }

    static testMethod void testBranchWhenNoTag()
    {
        UnitTest.createTestData(acct).many(6).branch('individual account|organization account|household account');
        UnitTest.get(Backlog__c.SObjectType).dummyInsert();

        Integer numIndividual = 0;
        Integer numOrganization = 0;
        Integer numHousehold = 0;

        for(SObject account : UnitTest.get(Backlog__c.SObjectType).getList())
        {
            if(UnitTest.analyze('individual account').hasId(account.ID))
                numIndividual++;
            else if(UnitTest.analyze('organization account').hasId(account.ID))
                numOrganization++;
            else  if(UnitTest.analyze('household account').hasId(account.ID))
                numHousehold++; 
        }

        System.assertEquals(2, numIndividual, 'The branch function must correctly split partitions across unique groupings of tags');
        System.assertEquals(2, numOrganization, 'The branch function must correctly split partitions across unique groupings of tags');
        System.assertEquals(2, numHousehold, 'The branch function must correctly split partitions across unique groupings of tags');
    }

    static testMethod void testBranch_MultipleExistingTags()
    {
        UnitTest.createTestData(acct).many(6).tag('rich accounts');
        UnitTest.createTestData(acct).many(6).tag('rich accounts').tag('my accounts');
        UnitTest.createTestData(acct).many(6).tag('poor accounts').tag('my accounts').tag('unmanaged accounts');

        UnitTest.get(Backlog__c.SObjectType).dummyInsert();

        UnitTest.get(Backlog__c.SObjectType).branch('new accounts|old accounts');

        Integer numRichNewAccounts = 0;
        Integer numRichOldAccounts = 0;
        Integer numMyRichNewAccounts = 0;
        Integer numMyRichOldAccounts = 0;
        Integer numMyPoorUnmanagedNewAccounts = 0;
        Integer numMyPoorUnmanagedOldAccounts = 0;

        for(SObject account : UnitTest.get(Backlog__c.SObjectType).getList())
        {
            Set<String> tags = new Set<String>();

            if(UnitTest.analyze('rich accounts').hasId(account.ID))
                tags = UnitTest.analyze('rich accounts').selectByID(account.ID).getTags();
            else
                tags = UnitTest.analyze('poor accounts').selectByID(account.ID).getTags();

            if(tags.contains('rich accounts') && tags.contains('new accounts') && tags.size()==2)
            {
                numRichNewAccounts++;
            }
            else if(tags.contains('rich accounts') && tags.contains('old accounts')  && tags.size()==2)
            {
                numRichOldAccounts++;
            }
            else if(tags.contains('rich accounts') && tags.contains('new accounts') && tags.contains('my accounts') && tags.size()==3)
            {
                numMyRichNewAccounts++;
            }
            else if(tags.contains('rich accounts') && tags.contains('old accounts') && tags.contains('my accounts') && tags.size()==3)
            {
                numMyRichOldAccounts++;
            }
            else if(tags.contains('poor accounts') && tags.contains('new accounts') && tags.contains('unmanaged accounts')
                    && tags.contains('my accounts') && tags.size()==4)
            {
                numMyPoorUnmanagedNewAccounts++;
            }
            else if(tags.contains('poor accounts') && tags.contains('old accounts') && tags.contains('unmanaged accounts')
                    && tags.contains('my accounts') && tags.size()==4)
            {
                numMyPoorUnmanagedOldAccounts++;
            }
            else
            {
                System.assert(false,'The branch function must work correctly and spread the new charecteristic tags across all unique samples. Instead, we are seeing this:'+tags);
            }
        }

        System.assertEquals(3, numRichNewAccounts, 'The branch function must correctly split partitions across unique groupings of tags');
        System.assertEquals(3, numRichOldAccounts, 'The branch function must correctly split partitions across unique groupings of tags');
        System.assertEquals(3, numMyRichNewAccounts, 'The branch function must correctly split partitions across unique groupings of tags');
        System.assertEquals(3, numMyRichOldAccounts, 'The branch function must correctly split partitions across unique groupings of tags');
        System.assertEquals(3, numMyPoorUnmanagedNewAccounts, 'The branch function must correctly split partitions across unique groupings of tags');
        System.assertEquals(3, numMyPoorUnmanagedOldAccounts, 'The branch function must correctly split partitions across unique groupings of tags');
    }

    static testMethod void testBranch_OddPartitionResults()
    {
        UnitTest.createTestData(acct).many(7).tag('accounts').dummyInsert();
        UnitTest.get('accounts').branch('individual accounts|organization accounts');

        Integer numIndividualaccounts = 0;
        Integer numOrgaccounts = 0;
        for(SObject account : UnitTest.get('accounts').getList())
        {
            Set<String> tags  = UnitTest.analyze('accounts').selectByID(account.ID).getTags();
            System.assertEquals(2,tags.size(), 'The branch function must not create or delete any tags other than what are specified');
            if(tags.contains('individual accounts'))
                numIndividualaccounts++;
            else if(tags.contains('organization accounts'))
                numOrgaccounts++;
        }
        System.assertEquals(4, numIndividualaccounts, 'The branch function must work even when there is an uneven split');
        System.assertEquals(3, numOrgaccounts, 'The branch function must work even when there is an uneven split');
    }

    static testMethod void testBranch()
    {
        UnitTest.createTestData(acct).many(40).tag('accounts').dummyInsert();
        UnitTest.get('accounts').branch('red accounts|green accounts');
        UnitTest.get('accounts').branch('big accounts|small accounts').branch('new accounts | old accounts');
        
        assertBranchWorksForColorSizeAgeDivisions(40/8);
    }

    static testMethod void testBranchAfterDivide()
    {
        UnitTest.createTestData(acct).many(48).dummyInsert();

        UnitTest.get(Backlog__c.SObjectType).tag('accounts').divide(2).part('new accounts').part('old accounts');
        UnitTest.get('accounts').branch('red accounts|green accounts').branch('big accounts|small accounts');

        assertBranchWorksForColorSizeAgeDivisions(48/8);
    }

    static testMethod void testBranchOnDividedParts()
    {
        UnitTest.createTestData(acct).many(48).tag('accounts').dummyInsert();

        UnitTest.get(Backlog__c.SObjectType).divide(2).part('big accounts').part('small accounts');
        UnitTest.get('big accounts').branch('red accounts|green accounts').branch('new accounts|old accounts');
        UnitTest.get('small accounts').branch('red accounts|green accounts').branch('new accounts|old accounts');

        assertBranchWorksForColorSizeAgeDivisions(48/8);
    }

    static void assertBranchWorksForColorSizeAgeDivisions(Integer expectedPartionSize) {
        Integer countRedBigNewAccounts = 0;
        Integer countRedSmallNewAccounts = 0;
        Integer countRedBigOldAccounts = 0;
        Integer countRedSmallOldAccounts = 0;
        Integer countGreenBigNewAccounts = 0;
        Integer countGreenSmallNewAccounts = 0;
        Integer countGreenBigOldAccounts = 0;
        Integer countGreenSmallOldAccounts = 0;

        for(SObject account : UnitTest.get('accounts').getList())
        {
            Set<String> tags  = UnitTest.analyze('accounts').selectByID(account.ID).getTags();
            System.assertEquals(4, tags.size(), 'The branch functions must tag data correctly');
            System.assert(tags.contains('accounts'),'Existing tags should be unaffected by the branch tool');
            
            if(tags.contains('red accounts') && tags.contains('big accounts') && tags.contains('new accounts'))  
                countRedBigNewAccounts++;
            else if(tags.contains('red accounts') && tags.contains('small accounts') && tags.contains('new accounts'))  
                countRedSmallNewAccounts++;
            else if(tags.contains('red accounts') && tags.contains('big accounts') && tags.contains('old accounts'))  
                countRedBigOldAccounts++;
            else if(tags.contains('red accounts') && tags.contains('small accounts') && tags.contains('old accounts'))  
                countRedSmallOldAccounts++;
            else if(tags.contains('green accounts') && tags.contains('big accounts') && tags.contains('new accounts'))  
                countGreenBigNewAccounts++;
            else if(tags.contains('green accounts') && tags.contains('small accounts') && tags.contains('new accounts'))  
                countGreenSmallNewAccounts++;
            else if(tags.contains('green accounts') && tags.contains('big accounts') && tags.contains('old accounts'))  
                countGreenBigOldAccounts++;
            else if(tags.contains('green accounts') && tags.contains('small accounts') && tags.contains('old accounts'))  
                countGreenSmallOldAccounts++;
            else 
                System.assert(false,'The branch function must create only the specified tags, and preserve any existing tags.');
        }

        System.assertEquals(expectedPartionSize, countRedBigNewAccounts, 'The branch function must correctly result in the right number of permutations and must cleanly distribute the tags');
        System.assertEquals(expectedPartionSize, countRedSmallNewAccounts, 'The branch function must correctly result in the right number of permutations and must cleanly distribute the tags');
        System.assertEquals(expectedPartionSize, countRedBigOldAccounts, 'The branch function must correctly result in the right number of permutations and must cleanly distribute the tags');
        System.assertEquals(expectedPartionSize, countRedSmallOldAccounts, 'The branch function must correctly result in the right number of permutations and must cleanly distribute the tags');
        System.assertEquals(expectedPartionSize, countGreenBigNewAccounts, 'The branch function must correctly result in the right number of permutations and must cleanly distribute the tags');
        System.assertEquals(expectedPartionSize, countGreenSmallNewAccounts, 'The branch function must correctly result in the right number of permutations and must cleanly distribute the tags');
        System.assertEquals(expectedPartionSize, countGreenBigOldAccounts, 'The branch function must correctly result in the right number of permutations and must cleanly distribute the tags');
        System.assertEquals(expectedPartionSize, countGreenSmallOldAccounts, 'The branch function must correctly result in the right number of permutations and must cleanly distribute the tags');
    }
}