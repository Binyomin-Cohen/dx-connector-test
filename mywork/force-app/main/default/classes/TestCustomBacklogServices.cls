@isTest
private class TestCustomBacklogServices {

    private static Custom_Backlog__c customBacklog;
    private static Custom_Backlog__c customBacklog2;
    private static List<Custom_Backlog__c> orderedCustomBacklog;

    private static void setup(){
        customBacklog = TestingUtils.createCustomBacklog('z_test');
        customBacklog2 = TestingUtils.createCustomBacklog('a_test');
        orderedCustomBacklog = new List<Custom_Backlog__c> {customBacklog2, customBacklog};
    }

    static testMethod void loadSortedCustomBacklogs_withState() {
        setup();

        List<Custom_Backlog__c> orderedCustomBacklogIds = new List<Custom_Backlog__c>{ customBacklog2, customBacklog };
        List<String> sortedCustomBacklogIds = new List<String>{ customBacklog.Id, customBacklog2.Id };
        CustomBacklogServices.CustomBacklogSort customBacklogSort =
                new CustomBacklogServices.CustomBacklogSort(sortedCustomBacklogIds);
        State.store(customBacklogSort);

        Test.startTest();
            List<Custom_Backlog__c> sortedCustomBacklogs =
                    CustomBacklogServices.loadSortedCustomBacklogs(orderedCustomBacklogIds);
        Test.stopTest();

        System.assertEquals(customBacklogSort.getIds().size(), sortedCustomBacklogs.size(),
                'The sorted size should be the same size as the state size.');

        for (Integer k = 0; k < sortedCustomBacklogs.size(); k++) {
            System.assertEquals(sortedCustomBacklogIds[k], sortedCustomBacklogs[k].Id,
                    'The sorted order should be correct.');
        }
    }

    static testMethod void loadSortedCustomBacklogs_noState() {
        setup();

        Test.startTest();
            List<Custom_Backlog__c> sortedCustomBacklogs =
                    CustomBacklogServices.loadSortedCustomBacklogs(orderedCustomBacklog);
        Test.stopTest();

        System.assertEquals(orderedCustomBacklog.size(), sortedCustomBacklogs.size(),
                'The sorted size should be the same size as the ordered ids list size.');

        for (Integer k = 0; k < sortedCustomBacklogs.size(); k++) {
            System.assertEquals(orderedCustomBacklog[k].Id, sortedCustomBacklogs[k].Id,
                    'The sorted order should be the same as the ordered list order since this was not sorted.');
        }

    }

    static testMethod void loadSortedCustomBacklogs_intermittent_newCustomBacklog() {
        setup();

        Custom_Backlog__c newCustomBacklog = TestingUtils.createCustomBacklog('h_test');
        orderedCustomBacklog =
                new List<Custom_Backlog__c>{ customBacklog2, newCustomBacklog, customBacklog };

        List<String> sortedCustomBacklogIds = new List<String>{ customBacklog.Id, customBacklog2.Id };
        CustomBacklogServices.CustomBacklogSort customBacklogSort =
                new CustomBacklogServices.CustomBacklogSort(sortedCustomBacklogIds);
        State.store(customBacklogSort);

        Test.startTest();
            List<Custom_Backlog__c> sortedCustomBacklogs
                    = CustomBacklogServices.loadSortedCustomBacklogs(orderedCustomBacklog);
        Test.stopTest();

        System.assertEquals(orderedCustomBacklog.size(), sortedCustomBacklogs.size(),
                'The sorted size should be the same size as the total backlog count.');

        for (Integer k = 0; k < sortedCustomBacklogs.size(); k++) {
            if (k < sortedCustomBacklogIds.size()) {
                System.assertEquals(sortedCustomBacklogIds[k], sortedCustomBacklogs[k].Id,
                        'The first few custom backlogs should be sorted according to the order saved in state.');
            } else {
                System.assertEquals(newCustomBacklog.Id, sortedCustomBacklogs[k].Id,
                        'The last custom backlog should match the backlog not in state.');
            }
        }
    }

    static testMethod void loadSortedCustomBacklogs_intermittent_removedCustomBacklog() {
        setup();

        Custom_Backlog__c removedCustomBacklog = TestingUtils.createCustomBacklog('zz_test');

        List<String> sortedCustomBacklogIds = new List<String>{ customBacklog.Id, removedCustomBacklog.Id, customBacklog2.Id };
        CustomBacklogServices.CustomBacklogSort customBacklogSort =
                new CustomBacklogServices.CustomBacklogSort(sortedCustomBacklogIds);
        State.store(customBacklogSort);

        Test.startTest();
            List<Custom_Backlog__c> sortedCustomBacklogs
                    = CustomBacklogServices.loadSortedCustomBacklogs(orderedCustomBacklog);
        Test.stopTest();

        System.assertEquals(orderedCustomBacklog.size(), sortedCustomBacklogs.size(),
                'The sorted size should be the same size as the passed in ordered custom backlog list size.');
        System.assertEquals(sortedCustomBacklogIds[0], sortedCustomBacklogs[0].Id,
                'The returned sorted list should still retain ordered Custom Backlogs.');
        System.assertEquals(sortedCustomBacklogIds[2], sortedCustomBacklogs[1].Id,
                'The returned sorted list should still retain ordered Custom Backlogs.');
    }

    static testMethod void loadSortedCustomBacklogs_emptyState() {
        setup();

        CustomBacklogServices.CustomBacklogSort customBacklogSort =
                new CustomBacklogServices.CustomBacklogSort();
        State.store(customBacklogSort);

        Test.startTest();
            List<Custom_Backlog__c> sortedCustomBacklogs
                    = CustomBacklogServices.loadSortedCustomBacklogs(orderedCustomBacklog);
        Test.stopTest();

        System.assertEquals(orderedCustomBacklog.size(), sortedCustomBacklogs.size());
        for (Integer k = 0; k < sortedCustomBacklogs.size(); k++) {
        	System.assertEquals(orderedCustomBacklog[k].Id, sortedCustomBacklogs[k].Id,
        			'The order of the sorted and default ordered custom backlogs should be the same.');
        }
    }

    public static testMethod void updateCustomBacklogSortState() {
        setup();

        List<String> sortedCustomBacklogIds = new List<String> { customBacklog.Id , customBacklog2.Id };
        Test.startTest();
            CustomBacklogServices.updateCustomBacklogSortState(
            		sortedCustomBacklogIds[0] + ',' + sortedCustomBacklogIds[1] );
        Test.stopTest();

        CustomBacklogServices.CustomBacklogSort customBacklogSort =
                new CustomBacklogServices.CustomBacklogSort();

        try {
            State.retrieve(customBacklogSort);
        } catch (State.StateException se) {
            System.assert(false, 'A state should have been saved, no exception should have been caught');
        }

        List<String> sortedStateCustomBacklogIds = customBacklogSort.getIds();

        System.assertEquals(sortedCustomBacklogIds.size(), sortedStateCustomBacklogIds.size(),
        		'The size of the state list should match the size of the passed in Ids list.');

        for (Integer k = 0; k < sortedStateCustomBacklogIds.size(); k++) {
	    	System.assertEquals(sortedCustomBacklogIds[k], sortedStateCustomBacklogIds[k],
	        		'The custom backlog id in the state should match the order of the passed in order.');
        }
    }

    public static testMethod void updateCustomBacklogSortState_emptyUpdate() {
        setup();

        List<String> defaultSavedIds = new List<String>{ customBacklog.Id, customBacklog2.Id };
        CustomBacklogServices.CustomBacklogSort customBacklogSort =
                new CustomBacklogServices.CustomBacklogSort( defaultSavedIds );
        State.store(customBacklogSort);

        Test.startTest();
            CustomBacklogServices.updateCustomBacklogSortState( '' );
        Test.stopTest();

        try {
            State.retrieve(customBacklogSort);
        } catch (State.StateException se) {
            System.assert(false, 'A state should have been saved, no exception should have been caught');
        }

        System.assert( customBacklogSort.getIds().isEmpty(),
        		'The stored size should be empty.');
    }

    public static testMethod void updateCustomBacklogSortState_nullParameter() {
    	Test.startTest();
        	CustomBacklogServices.updateCustomBacklogSortState( null );
        Test.stopTest();

        CustomBacklogServices.CustomBacklogSort customBacklogSort =
                new CustomBacklogServices.CustomBacklogSort();

        try {
            State.retrieve(customBacklogSort);
            System.assert(false, 'A state should not have been saved when a null parameter was passed in.');
        } catch (State.StateException se) {
            System.assertEquals(State.STATE_NOT_FOUND, se.getMessage(),
            		'An exception with state not found message should have been caught and returned.');
        }
    }

    public static testMethod void masterBacklogProperty_noExistingUniversalBacklog() {
    	Test.startTest();
        	try{
                Custom_Backlog__c testUniversal = CustomBacklogServices.MASTER_BACKLOG_RECORD;
                System.assert(false, 'An exception should be thrown');
            } catch (ALMException aex ){
                System.assertEquals(CustomBacklogServices.MISSING_UNIVERSAL_BACKLOG_MESSAGE, aex.getMessage(), 'The correct exception message should be shown');
            }
        Test.stopTest();
    }

    public static testMethod void masterBacklogProperty_existingUniversalBacklog() {
    	Custom_Backlog__c existingUniversalBacklog = TestingUtils.buildCustomBacklog('Test_U');
        existingUniversalBacklog.Universal__c = true;
        insert existingUniversalBacklog;
        Custom_Backlog__c actualUniversal;

        Test.startTest();
        	try{
                actualUniversal = CustomBacklogServices.MASTER_BACKLOG_RECORD;
            } catch (ALMException aex ){
                System.assert(false, 'No exception should be thrown');
            }
        Test.stopTest();

        System.assertEquals(existingUniversalBacklog.Id, actualUniversal.Id, 'The correct universal backlog should be found');
    }

    public static testMethod void createUniversalBacklog_existingUniversalBacklog() {
    	Custom_Backlog__c existingUniversalBacklog = TestingUtils.buildCustomBacklog('Test_U');
        existingUniversalBacklog.Universal__c = true;
        insert existingUniversalBacklog;

        Test.startTest();
        	CustomBacklogServices.createUniversalBacklogIfMissing();
        Test.stopTest();

        System.assertEquals(1, [Select Id FROM Custom_Backlog__c where Universal__c = true].size(), 'Only one universal backlog should exist');
        System.assertEquals(existingUniversalBacklog.Id, CustomBacklogServices.MASTER_BACKLOG_RECORD.Id, 'The correct universal backlog should be found');
    }

    public static testMethod void createUniversalBacklog_noExistingUniversalBacklog() {

        Test.startTest();
        	CustomBacklogServices.createUniversalBacklogIfMissing();
        Test.stopTest();

        List<Custom_Backlog__c> actualUniversalBacklogs = [Select Id, Name FROM Custom_Backlog__c where Universal__c = true];

        System.assertEquals(1, actualUniversalBacklogs.size(), 'Only one universal backlog should exist');

        Custom_Backlog__c actualUniversalBacklog = actualUniversalBacklogs[0];

        System.assertEquals(Label.Backlog_Default_Name, actualUniversalBacklog.Name, 'The name of the custom backlog should be correct');

    }
}