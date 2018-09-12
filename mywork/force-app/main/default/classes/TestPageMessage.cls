@isTest
private class TestPageMessage {
    static testMethod void PageMessage_standardSeverity_info() {
        String testContent = 'Test Content';

        Test.startTest();
            PageMessage testMessage = new PageMessage(ApexPages.Severity.INFO, testContent);
        Test.stopTest();

        System.assertEquals(ApexPages.Severity.INFO.name().toLowerCase(), testMessage.messageType, 'The types should match.');
        System.assertEquals(testContent, testMessage.message, 'The content should match.');
        System.assertEquals(null, testMessage.messageId, 'The ID should be null by default.');
        System.assertEquals(true, testMessage.showCloseButton, 'The show close button should be true by default.');
    }

    static testMethod void PageMessage_standardSeverity_error() {
        String testContent = 'Test Content';

        Test.startTest();
            PageMessage testMessage = new PageMessage(ApexPages.Severity.ERROR, testContent);
        Test.stopTest();

        System.assertEquals(ApexPages.Severity.ERROR.name().toLowerCase(), testMessage.messageType, 'The types should match.');
        System.assertEquals(testContent, testMessage.message, 'The content should match.');
        System.assertEquals(null, testMessage.messageId, 'The ID should be null by default.');
        System.assertEquals(true, testMessage.showCloseButton, 'The show close button should be true by default.');
    }

    static testMethod void PageMessage_standardSeverity_fatal() {
        String testContent = 'Test Content';

        Test.startTest();
            PageMessage testMessage = new PageMessage(ApexPages.Severity.FATAL, testContent);
        Test.stopTest();

        System.assertEquals(ApexPages.Severity.ERROR.name().toLowerCase(), testMessage.messageType, 'The type should be set to "error".');
        System.assertEquals(testContent, testMessage.message, 'The content should match.');
        System.assertEquals(null, testMessage.messageId, 'The ID should be null by default.');
        System.assertEquals(true, testMessage.showCloseButton, 'The show close button should be true by default.');
    }

    static testMethod void PageMessage_customSeverity_success() {
        String testContent = 'Test Content';

        Test.startTest();
            PageMessage testMessage = new PageMessage(PageMessage.Severity.SUCCESS, testContent);
        Test.stopTest();

        System.assertEquals(PageMessage.Severity.SUCCESS.name().toLowerCase(), testMessage.messageType, 'The types should match.');
        System.assertEquals(testContent, testMessage.message, 'The content should match.');
        System.assertEquals(null, testMessage.messageId, 'The ID should be null by default.');
        System.assertEquals(true, testMessage.showCloseButton, 'The show close button should be true by default.');
    }

    static testMethod void PageMessage_showCloseButton() {
        String testContent = 'Test Content';

        Test.startTest();
            PageMessage testMessage = new PageMessage(ApexPages.Severity.INFO, testContent, false);
        Test.stopTest();

        System.assertEquals(ApexPages.Severity.INFO.name().toLowerCase(), testMessage.messageType, 'The types should match.');
        System.assertEquals(testContent, testMessage.message, 'The content should match.');
        System.assertEquals(false, testMessage.showCloseButton, 'The show close button should match.');
        System.assertEquals(null, testMessage.messageId, 'The ID should be null by default.');
    }

    static testMethod void PageMessage_ID() {
        String testId = 'Test ID';
        String testContent = 'Test Content';

        Test.startTest();
            PageMessage testMessage = new PageMessage(testId, ApexPages.Severity.INFO, testContent, false);
        Test.stopTest();

        System.assertEquals(testId, testMessage.messageId, 'The ID should match.');
        System.assertEquals(ApexPages.Severity.INFO.name().toLowerCase(), testMessage.messageType, 'The types should match.');
        System.assertEquals(testContent, testMessage.message, 'The content should match.');
        System.assertEquals(false, testMessage.showCloseButton, 'The show close button should match.');
    }

    static testMethod void compareTo_neitherNull_thisLessThanThat() {
        Long baseTime = DateTime.now().getTime();

        PageMessage thisMessage = new PageMessage(ApexPages.Severity.INFO, 'Test Content');
        PageMessage thatMessage = new PageMessage(ApexPages.Severity.INFO, 'Test Content');
        thisMessage.createdTime = baseTime;
        thatMessage.createdTime = baseTime + 1;

        Test.startTest();
            Integer result = thisMessage.compareTo(thatMessage);
        Test.stopTest();

        System.assert((result < 0), 'This message should be lesser than that message.');
    }

    static testMethod void compareTo_neitherNull_thisGreaterThanThat() {
        Long baseTime = DateTime.now().getTime();

        PageMessage thisMessage = new PageMessage(ApexPages.Severity.INFO, 'Test Content');
        PageMessage thatMessage = new PageMessage(ApexPages.Severity.INFO, 'Test Content');
        thisMessage.createdTime = baseTime + 1;
        thatMessage.createdTime = baseTime;

        Test.startTest();
            Integer result = thisMessage.compareTo(thatMessage);
        Test.stopTest();

        System.assert((result > 0), 'This message should be greater than that message.');
    }

    static testMethod void compareTo_neitherNull_thisEqualToThat() {
        Long baseTime = DateTime.now().getTime();
        
        PageMessage thisMessage = new PageMessage(ApexPages.Severity.INFO, 'Test Content');
        PageMessage thatMessage = new PageMessage(ApexPages.Severity.INFO, 'Test Content');
        thisMessage.createdTime = baseTime;
        thatMessage.createdTime = baseTime;

        Test.startTest();
            Integer result = thisMessage.compareTo(thatMessage);
        Test.stopTest();

        System.assert((result == 0), 'This message should be equal to that message.');
    }

    static testMethod void compareTo_thisNull() {
        Long baseTime = DateTime.now().getTime();
        
        PageMessage thisMessage = new PageMessage(ApexPages.Severity.INFO, 'Test Content');
        PageMessage thatMessage = new PageMessage(ApexPages.Severity.INFO, 'Test Content');
        thisMessage.createdTime = null;
        thatMessage.createdTime = baseTime;

        Test.startTest();
            Integer result = thisMessage.compareTo(thatMessage);
        Test.stopTest();

        System.assert((result < 0), 'This null message should be less than that non-null message.');
    }

    static testMethod void compareTo_thatNull() {
        Long baseTime = DateTime.now().getTime();
        
        PageMessage thisMessage = new PageMessage(ApexPages.Severity.INFO, 'Test Content');
        PageMessage thatMessage = new PageMessage(ApexPages.Severity.INFO, 'Test Content');
        thisMessage.createdTime = baseTime;
        thatMessage.createdTime = null;

        Test.startTest();
            Integer result = thisMessage.compareTo(thatMessage);
        Test.stopTest();

        System.assert((result > 0), 'This non-null message should be less than that null message.');
    }

    static testMethod void compareTo_bothNull() {
        PageMessage thisMessage = new PageMessage(ApexPages.Severity.INFO, 'Test Content');
        PageMessage thatMessage = new PageMessage(ApexPages.Severity.INFO, 'Test Content');
        thisMessage.createdTime = null;
        thatMessage.createdTime = null;

        Test.startTest();
            Integer result = thisMessage.compareTo(thatMessage);
        Test.stopTest();

        System.assert((result == 0), 'This null message should be equal to that null message.');
    }
}