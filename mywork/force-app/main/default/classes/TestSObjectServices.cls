@isTest
private class TestSObjectServices {
    static String tagBacklogItems = 'Backlog Items';
    static String tagBacklogItemsPart0 = 'Backlog Items Part 0';
    static String tagBacklogItemsPart1 = 'Backlog Items Part 1';

    static void setupBacklogData() {
        UnitTest.addData(TestingUtils.buildBacklogItems(10)).tag(tagBacklogItems);
        UnitTest.get(tagBacklogItems)
            .divide(2)
            .part(tagBacklogItemsPart0)
            .part(tagBacklogItemsPart1);
        UnitTest.get(tagBacklogItems).dummyInsert();
    }

    static testMethod void chunkLists_smallList() {
        List<SObject> sobjs = new List<Backlog__c> {
            new Backlog__c(),
            new Backlog__c()
        };

        Test.startTest();
            List<List<SObject>> chunks = SObjectServices.chunkLists(sobjs, 3);
        Test.stopTest();

        System.assertEquals(1, chunks.size(), 'The list should be broken into 1 chunk');
        System.assertEquals(2, chunks[0].size(), 'All items should be included');
    }

    static testMethod void chunkLists_fullList() {
        List<SObject> sobjs = new List<Backlog__c> {
            new Backlog__c(),
            new Backlog__c(),
            new Backlog__c()
        };

        Test.startTest();
            List<List<SObject>> chunks = SObjectServices.chunkLists(sobjs, 3);
        Test.stopTest();

        System.assertEquals(1, chunks.size(), 'The list should be broken into 1 chunk');
        System.assertEquals(3, chunks[0].size(), 'All items should be included');
    }

    static testMethod void chunkLists_multipleLists() {
        List<SObject> sobjs = new List<Backlog__c> {
            new Backlog__c(),
            new Backlog__c(),
            new Backlog__c(),
            new Backlog__c()
        };

        Test.startTest();
            List<List<SObject>> chunks = SObjectServices.chunkLists(sobjs, 3);
        Test.stopTest();

        System.assertEquals(2, chunks.size(), 'The list should be broken into 1 chunk');
        System.assertEquals(3, chunks[0].size(), 'All items should be included');
        System.assertEquals(1, chunks[1].size(), 'All items should be included');
    }
    static testMethod void chunkLists_multipleFullLists() {
        List<SObject> sobjs = new List<Backlog__c> {
            new Backlog__c(),
            new Backlog__c(),
            new Backlog__c(),
            new Backlog__c(),
            new Backlog__c(),
            new Backlog__c()
        };

        Test.startTest();
            List<List<SObject>> chunks = SObjectServices.chunkLists(sobjs, 3);
        Test.stopTest();

        System.assertEquals(2, chunks.size(), 'The list should be broken into 1 chunk');
        System.assertEquals(3, chunks[0].size(), 'All items should be included');
        System.assertEquals(3, chunks[1].size(), 'All items should be included');
    }

    static testMethod void testFilterObjectsWithFieldUpdate_insertAndDelete() {
        setupBacklogData();

        Test.startTest();
            List<Sprint_Item__c> filteredBacklogItems = SObjectServices.filterObjectsWithFieldUpdate(
                (List<Backlog__c>)UnitTest.get(tagBacklogItems).getList(), null, Schema.Backlog__c.Status__c);
        Test.stopTest();

        UnitTest.analyze(tagBacklogItems).assertEquivalence(filteredBacklogItems, 'We expect to get back all objects on insertion.');
    }

    static testMethod void testFilterObjectsWithFieldUpdate_update_NoFieldUpdate() {
        setupBacklogData();

        Map<Id, Backlog__c> oldMap = new Map<Id, Backlog__c>((List<Backlog__c>)UnitTest.get(tagBacklogItems).getList().deepClone(true));

        UnitTest.get(tagBacklogItemsPart0).property(SObjectServices.getFullyQualifiedName('Summary__c')).assign('Some Summary');

        Test.startTest();
            List<Sprint_Item__c> filteredSprintItems = SObjectServices.filterObjectsWithFieldUpdate(
                (List<Sprint_Item__c>)UnitTest.get(tagBacklogItems).getList(), oldMap, Schema.Backlog__c.Status__c);
        Test.stopTest();

        System.assert(filteredSprintItems.isEmpty(), 'We expect to get back no objects when there are no relevant updates.');
    }

    static testMethod void testFilterObjectsWithFieldUpdate_update_fieldUpdate() {
        setupBacklogData();

        Map<Id, Backlog__c> oldMap = new Map<Id, Backlog__c>((List<Backlog__c>)UnitTest.get(tagBacklogItems).getList().deepClone(true));

        UnitTest.get(tagBacklogItemsPart0).property(SObjectServices.getFullyQualifiedName('Status__c')).assign('Open');

        Test.startTest();
            List<Sprint_Item__c> filteredSprintItems = SObjectServices.filterObjectsWithFieldUpdate(
                (List<Sprint_Item__c>)UnitTest.get(tagBacklogItems).getList(), oldMap, Schema.Backlog__c.Status__c);
        Test.stopTest();

        UnitTest.analyze(tagBacklogItemsPart0).assertEquivalence(filteredSprintItems, 'We expect to get back objects that have relevant updates.');
    }

    static testMethod void updateSObjectsAllowingPartialSuccess() {
        Test.setMock(HttpCalloutMock.class, new MockWebAssemblerAPI(MockWebAssemblerAPI.LOG_ACTION));

        // Create an invalid Id for lookup to cause DML error.
        Instances__c instance = TestingUtils.createInstance('test instance');
        Id instanceId = instance.Id;

        Backlog__c updateWillSucceed = TestingUtils.buildBacklogItem();
        Backlog__c updateWillFail = TestingUtils.buildBacklogItem();
        List<Backlog__c> backlogItems = new List<Backlog__c>{updateWillSucceed, updateWillFail};
        insert backlogItems;

        String SUCCESSFUL_UPDATE_VAL = 'will update';
        updateWillSucceed.Summary__c = SUCCESSFUL_UPDATE_VAL;
        updateWillFail.Summary__c = 'will fail to update';
        updateWillFail.Release__c = instanceId; // wrong type will cause update to fail

        String exceptionMessage;
        Test.startTest();
            try {
                SObjectServices.updateSObjectsAllowingPartialSuccess(backlogItems);
                System.assert(false, 'An Exception should have been thrown from the failed update');
            } catch (Exception e) {
                exceptionMessage = e.getMessage();
            }
        Test.stopTest();

        Map<Id, Backlog__c> requeriedBacklogItems = new Map<Id, Backlog__c>([SELECT Id, Summary__c from Backlog__c]);

        Backlog__c updatedBacklogItem = requeriedBacklogItems.get(updateWillSucceed.Id);
        System.assertEquals(SUCCESSFUL_UPDATE_VAL, updatedBacklogItem.Summary__c,
            'The update for the valid record should have succeeded');

        Backlog__c failedBacklogItem = requeriedBacklogItems.get(updateWillFail.Id);
        System.assert(String.isBlank(failedBacklogItem.Summary__c),
            'The update for the invalid record should have failed');

        System.assert(exceptionMessage.contains(failedBacklogItem.Id),
                      'The error message should mention the Jenkins Build that failed ' +
                      'to update. actual: ' + exceptionMessage);
        System.assert(!exceptionMessage.contains(updatedBacklogItem.Id),
            'The error message should not mention the Jenkins Build that successfully updated');
        System.assert(exceptionMessage.containsIgnoreCase('incorrect type'),
            'The error message should indicate that the type of Id was incorrect.');
    }

    static void testAndAssertQueryStringEquivalence( String expectedQuery, String query, String exceptionMessage ) {
        String actualQuery;

        Test.startTest();
            try{
                actualQuery = SObjectServices.getFullyQualifiedQuery(query);
            } catch (exception ex) {
                System.assert(false, 'No exceptions should be thrown');
            }
        Test.stopTest();

        System.assertEquals(expectedQuery, actualQuery, exceptionMessage);
    }

    static testMethod void getFullyQualifiedQuery() {
        SObjectServices.CURRENT_NAMESPACE = 'ALM_PM';
        String fullyQualifiedNamespace = SObjectServices.CURRENT_NAMESPACE + '__';

        String testQuery = 'SELECT Id, Name, Custom_Field1__c FROM Account__c Limit 1';

        String expectedQuery = 'SELECT Id, Name, '
                               +fullyQualifiedNamespace+'Custom_Field1__c FROM '
                               +fullyQualifiedNamespace+'Account__c Limit 1';

        testAndAssertQueryStringEquivalence( expectedQuery, testQuery, 'The query should be correctly namespaced' );
    }

    static testMethod void getFullyQualifiedQuery_null() {
        SObjectServices.CURRENT_NAMESPACE = 'ALM_PM';
        String fullyQualifiedNamespace = SObjectServices.CURRENT_NAMESPACE + '__';

        String testQuery = null;
        String expectedQuery = null;

        testAndAssertQueryStringEquivalence( expectedQuery, testQuery, 'Null should be returned if passed in with no exceptions' );
    }

    static testMethod void getFullyQualifiedQuery_empty() {
        SObjectServices.CURRENT_NAMESPACE = 'ALM_PM';
        String fullyQualifiedNamespace = SObjectServices.CURRENT_NAMESPACE + '__';

        String testQuery = '';

        String expectedQuery = '';

        testAndAssertQueryStringEquivalence( expectedQuery, testQuery, 'Empty should be returned if passed in with no exceptions' );
    }

    static testMethod void getFullyQualifiedQuery_relationship_fields() {
        SObjectServices.CURRENT_NAMESPACE = 'ALM_PM';
        String fullyQualifiedNamespace = SObjectServices.CURRENT_NAMESPACE + '__';

        String testQuery = 'SELECT Id, Name, Custom_Field1__r.CustomField__c FROM Account__c Limit 1';

        String expectedQuery = 'SELECT Id, Name, '
                                +fullyQualifiedNamespace+'Custom_Field1__r.'
                                +fullyQualifiedNamespace+'CustomField__c FROM '
                                +fullyQualifiedNamespace+'Account__c Limit 1';

        testAndAssertQueryStringEquivalence( expectedQuery, testQuery, 'The query should be correctly namespaced' );
    }

    static testMethod void getFullyQualifiedQuery_standard_object() {
        SObjectServices.CURRENT_NAMESPACE = 'ALM_PM';
        String fullyQualifiedNamespace = SObjectServices.CURRENT_NAMESPACE + '__';

        String testQuery = 'SELECT Id, Name, Custom_Field1__r.CustomField__c FROM Account Limit 1';

        String expectedQuery = 'SELECT Id, Name, '
                                +fullyQualifiedNamespace+'Custom_Field1__r.'
                                +fullyQualifiedNamespace+'CustomField__c FROM '
                                +'Account Limit 1';

        testAndAssertQueryStringEquivalence( expectedQuery, testQuery, 'The query should be correctly namespaced' );
    }

    static testMethod void getFullyQualifiedQuery_sub_query() {
        SObjectServices.CURRENT_NAMESPACE = 'ALM_PM';
        String fullyQualifiedNamespace = SObjectServices.CURRENT_NAMESPACE + '__';

        String testQuery = 'SELECT Id, '
                        +'(SELECT Custom_Backlog__c, Custom_Priority__c '
                         +'FROM Backlog_Items__r '
                         +'WHERE Custom_Priority__c != null '
                         +'ORDER BY Custom_Priority__c ASC '
                         +'LIMIT 1) '
                      +'FROM Custom_Backlog__c';

        String expectedQuery = 'SELECT Id, '
                                        +'(SELECT '
                                        +fullyQualifiedNamespace+'Custom_Backlog__c, '
                                        +fullyQualifiedNamespace+'Custom_Priority__c '
                                         +'FROM '
                                         +fullyQualifiedNamespace+'Backlog_Items__r '
                                         +'WHERE '+
                                         fullyQualifiedNamespace+'Custom_Priority__c != null '
                                         +'ORDER BY '+
                                         fullyQualifiedNamespace+'Custom_Priority__c ASC '
                                         +'LIMIT 1) '
                                      +'FROM '
                                      +fullyQualifiedNamespace+'Custom_Backlog__c';

        testAndAssertQueryStringEquivalence( expectedQuery, testQuery, 'The query should be correctly namespaced' );
    }

    private static void testFullyQualifiedName(String expectedFullyQualifiedName, String name, String assertionMessage) {
        Test.startTest();

            String fullyQualifiedName = SObjectServices.getFullyQualifiedName(name);

        Test.stopTest();

        System.assertEquals(expectedFullyQualifiedName, fullyQualifiedName, assertionMessage);
    }

    private static testMethod void getFullyQualifiedName_null() {
        testFullyQualifiedName(null, null, 'A null name should result in null.');
    }

    private static testMethod void getFullyQualifiedName_empty() {
        testFullyQualifiedName(null, '', 'An empty name should result in null.');
    }

    private static testMethod void getFullyQualifiedName_whitespace() {
        testFullyQualifiedName(null, ' ', 'A whitespace-only name should result in null.');
    }

    private static testMethod void getFullyQualifiedName_standard() {
        SObjectServices.CURRENT_NAMESPACE = 'alm_pm2';

        String standardName = 'Test_Name';

        testFullyQualifiedName(SObjectServices.CURRENT_NAMESPACE + '__' + standardName, standardName, 'A standard name should be properly qualified.');
    }

    private static testMethod void getFullyQualifiedName_custom_unqualified() {
        SObjectServices.CURRENT_NAMESPACE = 'alm_pm2';

        String customName = 'Test_Name__c';

        testFullyQualifiedName(SObjectServices.CURRENT_NAMESPACE + '__' + customName, customName, 'A custom name should be properly qualified.');
    }

    private static testMethod void getFullyQualifiedName_custom_qualified() {
        SObjectServices.CURRENT_NAMESPACE = 'alm_pm2';

        String customName = SObjectServices.CURRENT_NAMESPACE + '__Test_Name__c';

        testFullyQualifiedName(customName, customName, 'A custom name should be properly qualified.');
    }
    
    private static testMethod void getNameSpace() {
        SObjectServices.CURRENT_NAMESPACE = 'alm_pm2';

        System.assertEquals(SObjectServices.CURRENT_NAMESPACE + '__', SObjectServices.getNameSpace(), 'The namespace should be correctly populated');
    }
    
    private static testMethod void getNameSpace_empty() {
        SObjectServices.CURRENT_NAMESPACE = '';

        System.assertEquals(SObjectServices.CURRENT_NAMESPACE, SObjectServices.getNameSpace(), 'A blank namespace should be returned');
    }
}
