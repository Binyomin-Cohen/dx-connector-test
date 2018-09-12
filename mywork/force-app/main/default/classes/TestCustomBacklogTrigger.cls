@isTest
private class TestCustomBacklogTrigger {

    static testMethod void createDuplicateUniversalBacklog_one_existing() {
        Custom_Backlog__c testExistingUniversal = TestingUtils.buildCustomBacklog('testU');
        testExistingUniversal.Universal__c = true;
        insert testExistingUniversal;

        Custom_Backlog__c testDuplicateUniversal = TestingUtils.buildCustomBacklog('testU');
        testDuplicateUniversal.Universal__c = true;

        Custom_Backlog__c testRegularCustomBacklog = TestingUtils.buildCustomBacklog('testR');

        Test.startTest();
            try{
                insert new List<Custom_Backlog__c>{testDuplicateUniversal, testRegularCustomBacklog};
                System.assert(false, 'An exception should be thrown');
            } catch (DMLException dex) {
                System.assert(dex.getMessage().contains(CustomBacklogServices.UNIVERSAL_BACKLOG_ALREADY_EXISTS_MESSAGE), 'The exception message should be correct ' + dex.getMessage());
            }
        Test.stopTest();
    }

    static testMethod void createSingleUniversalBacklog_none_existing() {
        Custom_Backlog__c testExistingUniversal = TestingUtils.buildCustomBacklog('testU');
        testExistingUniversal.Universal__c = true;

        Custom_Backlog__c testRegularCustomBacklog = TestingUtils.buildCustomBacklog('testR');

        Test.startTest();
            try{
                insert new List<Custom_Backlog__c>{testExistingUniversal, testRegularCustomBacklog};
            } catch (DMLException dex) {
                System.assert(false, 'No exception should be thrown');
            }
        Test.stopTest();
    }

    static testMethod void createMultipleUniversalBacklogs_none_existing() {
        Custom_Backlog__c testExistingUniversal = TestingUtils.buildCustomBacklog('testU');
        testExistingUniversal.Universal__c = true;

        Custom_Backlog__c testExistingUniversal2 = TestingUtils.buildCustomBacklog('testU2');
        testExistingUniversal2.Universal__c = true;

        Test.startTest();
            try{
                insert new List<Custom_Backlog__c>{testExistingUniversal, testExistingUniversal2};
                System.assert(false, 'An exception should be thrown');
            } catch (DMLException dex) {
                System.assert(dex.getMessage().contains(CustomBacklogServices.UNIVERSAL_BACKLOG_ALREADY_EXISTS_MESSAGE), 'The exception message should be correct ' + dex.getMessage());
            }
        Test.stopTest();
    }

    static testMethod void updateDuplicateUniversalBacklog_one_existing() {
        Custom_Backlog__c testExistingUniversal = TestingUtils.buildCustomBacklog('testU');
        testExistingUniversal.Universal__c = true;
        insert testExistingUniversal;

        Custom_Backlog__c testDuplicateUniversal = TestingUtils.createCustomBacklog('testU');
        Custom_Backlog__c testRegularCustomBacklog = TestingUtils.createCustomBacklog('testR');

        testDuplicateUniversal.Universal__c = true;
        testRegularCustomBacklog.Name = 'testRU';

        Test.startTest();
            try{
                update new List<Custom_Backlog__c>{testDuplicateUniversal, testRegularCustomBacklog};
                System.assert(false, 'An exception should be thrown');
            } catch (DMLException dex) {
                System.assert(dex.getMessage().contains(CustomBacklogServices.UNIVERSAL_BACKLOG_ALREADY_EXISTS_MESSAGE), 'The exception message should be correct ' + dex.getMessage());
            }
        Test.stopTest();
    }

    static testMethod void updateSingleUniversalBacklog_none_existing() {
        Custom_Backlog__c testExistingUniversal = TestingUtils.createCustomBacklog('testU');
        Custom_Backlog__c testRegularCustomBacklog = TestingUtils.createCustomBacklog('testR');

        testExistingUniversal.Universal__c = true;
        testRegularCustomBacklog.Name = 'testRU';

        Test.startTest();
            try{
                update new List<Custom_Backlog__c>{testExistingUniversal, testRegularCustomBacklog};
            } catch (DMLException dex) {
                System.assert(false, 'No exception should be thrown');
            }
        Test.stopTest();
    }

    static testMethod void updateMultipleUniversalBacklogs_none_existing() {
        Custom_Backlog__c testExistingUniversal = TestingUtils.createCustomBacklog('testU');
        Custom_Backlog__c testExistingUniversal2 = TestingUtils.createCustomBacklog('testU2');

        testExistingUniversal.Universal__c = true;
        testExistingUniversal2.Universal__c = true;

        Test.startTest();
            try{
                update new List<Custom_Backlog__c>{testExistingUniversal, testExistingUniversal2};
                System.assert(false, 'An exception should be thrown');
            } catch (DMLException dex) {
                System.assert(dex.getMessage().contains(CustomBacklogServices.UNIVERSAL_BACKLOG_ALREADY_EXISTS_MESSAGE), 'The exception message should be correct ' + dex.getMessage());
            }
        Test.stopTest();
    }

    static testMethod void updateExistingUniversalBacklog() {
        Custom_Backlog__c testExistingUniversal = TestingUtils.buildCustomBacklog('testU');
        testExistingUniversal.Universal__c = true;
        insert testExistingUniversal;

        testExistingUniversal.Name = 'testUU';

        Test.startTest();
            try{
                update testExistingUniversal;
            } catch (DMLException dex) {
                System.assert(false, 'No exception should be thrown');
            }
        Test.stopTest();
    }

}
