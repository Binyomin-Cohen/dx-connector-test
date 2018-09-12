@isTest
private class TestALMPageMessages {

    static testMethod void addMessage_validID() {
        String testMessageId = 'Test Message ID';
        String testMessageContent = 'Test Message Content';
        PageMessage testMessage = new PageMessage(testMessageId, ApexPages.Severity.ERROR, testMessageContent, false);

        ALMPageMessages testPageMessageManager = new ALMPageMessages();
        Integer beforeSize = testPageMessageManager.getSize();

        Test.startTest();

            try {
                testPageMessageManager.addMessage(testMessage);
            } catch(Exception e) {
                System.assert(false, 'No exceptions should be thrown.');
            }

        Test.stopTest();

        System.assertEquals(beforeSize + 1, testPageMessageManager.getSize(), 'There should be one more message after adding a message.');

        PageMessage expectedMessage = testPageMessageManager.getMessageById(testMessageId);
        System.assertNotEquals(null, expectedMessage, 'A message with the given message ID should exist.');
        System.assertEquals('error', expectedMessage.messageType, 'The message type should match.');
        System.assertEquals(testMessageContent, expectedMessage.message, 'The message content should match.');
    }

    static testMethod void addMessage_noID() {
        String testMessageContent = 'Test Message Content';
        PageMessage testMessage = new PageMessage(ApexPages.Severity.ERROR, testMessageContent, false);

        ALMPageMessages testPageMessageManager = new ALMPageMessages();
        Integer beforeSize = testPageMessageManager.getSize();

        Test.startTest();

        try {
            testPageMessageManager.addMessage(testMessage);
        } catch (Exception e) {
            System.assert(false, 'No exceptions should be thrown.');
        }

        Test.stopTest();

        System.assertEquals(beforeSize + 1, testPageMessageManager.getSize(), 'There should be one additional message after adding a message.');

        PageMessage expectedMessage = null;
        for (PageMessage message : testPageMessageManager.messages) {
            if (message.message == testMessageContent) {
                expectedMessage = message;
            }
        }
        System.assertNotEquals(null, expectedMessage, 'A message with the message content should exist.');
        System.assertNotEquals(null, expectedMessage.messageId, 'The message ID should match.');
        System.assertEquals('error', expectedMessage.messageType, 'The message type should match.');
    }

    static testMethod void addMessage_null() {
        ALMPageMessages testPageMessageManager = new ALMPageMessages();
        Integer beforeSize = testPageMessageManager.getSize();

        Test.startTest();

        try {
            testPageMessageManager.addMessage(null);
        } catch (Exception e) {
            System.assert(false, 'No exceptions should be thrown.');
        }

        Test.stopTest();

        System.assertEquals(beforeSize, testPageMessageManager.getSize(), 'There should be no additional messages after failing to add a message.');
    }

    static testMethod void addMessages() {
        ALMPageMessages testPageMessageManager = new ALMPageMessages();
        Integer beforeSize = testPageMessageManager.getSize();

        PageMessage message0 = new PageMessage(ApexPages.Severity.ERROR, 'Content 0', false);
        PageMessage message1 = new PageMessage(ApexPages.Severity.ERROR, 'Content 1', false);
        PageMessage message2 = new PageMessage(ApexPages.Severity.ERROR, 'Content 2', false);
        Set<PageMessage> messages = new Set<PageMessage>{ message0, message1, message2 };

        Test.startTest();

        try {
            testPageMessageManager.addMessages(messages);
        } catch (Exception e) {
            System.assert(false, 'No exceptions should be thrown.');
        }

        System.assertEquals(beforeSize + messages.size(), testPageMessageManager.getSize(), 'All messages should be added.');
    }

    static testMethod void removeMessageById_validID() {
        String testMessageId = 'Test Message ID';
        String testMessageContent = 'Test Message Content';
        PageMessage testMessage = new PageMessage(testMessageId, ApexPages.Severity.ERROR, testMessageContent, false);

        ALMPageMessages testPageMessageManager = new ALMPageMessages();
        testPageMessageManager.addMessage(testMessage);
        Integer beforeSize = testPageMessageManager.getSize();

        Test.startTest();

            try {
                testPageMessageManager.removeMessageById(testMessageId);
            } catch(Exception e) {
                System.assert(false, 'No exceptions should be thrown.');
            }

        Test.stopTest();

        System.assertEquals(beforeSize - 1, testPageMessageManager.getSize(), 'There should be one fewer message after removing a message.');
    }

    static testMethod void removeMessageById_nullID() {
        String testMessageId = 'Test Message ID';
        String testMessageContent = 'Test Message Content';
        PageMessage testMessage = new PageMessage(testMessageId, ApexPages.Severity.ERROR, testMessageContent, false);

        ALMPageMessages testPageMessageManager = new ALMPageMessages();
        testPageMessageManager.addMessage(testMessage);
        Integer beforeSize = testPageMessageManager.getSize();

        Test.startTest();

            try {
                testPageMessageManager.removeMessageById(null);
            } catch (Exception e) {
                System.assert(false, 'No exceptions should be thrown.');
            }

        Test.stopTest();

        System.assertEquals(beforeSize, testPageMessageManager.getSize(), 'All messages should remain after not removing a message.');
    }

    static testMethod void removeMessageById_badID() {
        String testMessageId = 'Test Message ID';
        String testMessageContent = 'Test Message Content';
        PageMessage testMessage = new PageMessage(testMessageId, ApexPages.Severity.ERROR, testMessageContent, false);

        ALMPageMessages testPageMessageManager = new ALMPageMessages();
        testPageMessageManager.addMessage(testMessage);
        Integer beforeSize = testPageMessageManager.getSize();

        Test.startTest();

            try {
                testPageMessageManager.removeMessageById('Bad ID');
            } catch (Exception e) {
                System.assert(false, 'No exceptions should be thrown.');
            }

        Test.stopTest();

        System.assertEquals(beforeSize, testPageMessageManager.getSize(), 'All messages should remain after not removing a message.');
    }

    static testMethod void removeMessagesById() {
        ALMPageMessages testPageMessageManager = new ALMPageMessages();

        PageMessage message0 = new PageMessage(ApexPages.Severity.ERROR, 'Content 0', false);
        PageMessage message1 = new PageMessage(ApexPages.Severity.ERROR, 'Content 1', false);
        PageMessage message2 = new PageMessage(ApexPages.Severity.ERROR, 'Content 2', false);
        Set<PageMessage> messages = new Set<PageMessage>{ message0, message1, message2 };
        testPageMessageManager.addMessages(messages);

        Integer beforeSize = testPageMessageManager.getSize();

        Test.startTest();

        try {
            testPageMessageManager.removeMessagesById(new Set<String>{
                message0.messageId,
                message1.messageId,
                message2.messageId
            });
        } catch (Exception e) {
            System.assert(false, 'No exceptions should be thrown.');
        }

        System.assertEquals(beforeSize - messages.size(), testPageMessageManager.getSize(), 'All messages should be removed.');
    }

    static testMethod void getMessageById_validID() {
        String testMessageId = 'Test Message ID';
        String testMessageContent = 'Test Message Content';
        PageMessage testMessage = new PageMessage(testMessageId, ApexPages.Severity.ERROR, testMessageContent, false);

        ALMPageMessages testPageMessageManager = new ALMPageMessages();
        testPageMessageManager.addMessage(testMessage);
        Integer beforeSize = testPageMessageManager.getSize();

        PageMessage expectedMessage = null;
        Test.startTest();

            try {
                expectedMessage = testPageMessageManager.getMessageById(testMessageId);
            } catch (Exception e) {
                System.assert(false, 'No exceptions should be thrown.');
            }

        Test.stopTest();

        System.assertEquals(beforeSize, testPageMessageManager.getSize(), 'All messages should remain after retrieving a message.');

        System.assertNotEquals(null, expectedMessage, 'A message with the given message ID should exist.');
        System.assertEquals('error', expectedMessage.messageType, 'The message type should match.');
        System.assertEquals(testMessageContent, expectedMessage.message, 'The message content should match.');
    }

    static testMethod void getMessageById_nullID_notEmpty() {
        String testMessageId = 'Test Message ID';
        String testMessageContent = 'Test Message Content';
        PageMessage testMessage = new PageMessage(testMessageId, ApexPages.Severity.ERROR, testMessageContent, false);

        ALMPageMessages testPageMessageManager = new ALMPageMessages();
        Integer beforeSize = testPageMessageManager.getSize();

        PageMessage expectedMessage = null;
        Test.startTest();

            try {
                expectedMessage = testPageMessageManager.getMessageById(null);
            } catch (Exception e) {
                System.assert(false, 'No exceptions should be thrown.');
            }

        Test.stopTest();

        System.assertEquals(beforeSize, testPageMessageManager.getSize(), 'All messages should remain after retrieving a message.');
        System.assertEquals(null, expectedMessage, 'A message with a null message ID should not exist.');
    }

    static testMethod void getMessageById_badID_notEmpty() {
        String testMessageId = 'Test Message ID';
        String testMessageContent = 'Test Message Content';
        PageMessage testMessage = new PageMessage(testMessageId, ApexPages.Severity.ERROR, testMessageContent, false);

        ALMPageMessages testPageMessageManager = new ALMPageMessages();
        Integer beforeSize = testPageMessageManager.getSize();

        PageMessage expectedMessage = null;
        Test.startTest();

            try {
                expectedMessage = testPageMessageManager.getMessageById('Bad ID');
            } catch (Exception e) {
                System.assert(false, 'No exceptions should be thrown.');
            }

        Test.stopTest();

        System.assertEquals(beforeSize, testPageMessageManager.getSize(), 'All messages should remain after retrieving a message.');
        System.assertEquals(null, expectedMessage, 'A message with a bad message ID should not exist.');
    }

    static testMethod void getMessageById_null_empty() {
        ALMPageMessages testPageMessageManager = new ALMPageMessages();
        System.assertEquals(0, testPageMessageManager.getSize(), 'There should be no messages.');

        PageMessage expectedMessage = null;
        Test.startTest();

            try {
                expectedMessage = testPageMessageManager.getMessageById(null);
            } catch (Exception e) {
                System.assert(false, 'No exceptions should be thrown.');
            }

        Test.stopTest();

        System.assertEquals(0, testPageMessageManager.getSize(), 'There should be no messages.');
        System.assertEquals(null, expectedMessage, 'A message with a null message ID should not exist.');
    }

    static testMethod void getMessagesById() {
        String testMessageId0 = 'Test Message ID 0';
        String testMessageId1 = 'Test Message ID 1';
        String testMessageId2 = 'Test Message ID 2';

        ALMPageMessages testPageMessageManager = new ALMPageMessages();
        PageMessage message0 = new PageMessage(testMessageId0, ApexPages.Severity.ERROR, 'Content 0', false);
        PageMessage message1 = new PageMessage(testMessageId1, ApexPages.Severity.ERROR, 'Content 1', false);
        PageMessage message2 = new PageMessage(testMessageId2, ApexPages.Severity.ERROR, 'Content 2', false);

        Set<PageMessage> messages = new Set<PageMessage>{ message0, message1, message2 };
        testPageMessageManager.addMessages(messages);

        List<String> messageIds = new List<String>{ message0.messageId, message1.messageId };

        Integer beforeSize = testPageMessageManager.getSize();

        Test.startTest();

        List<PageMessage> actualMessages = null;
        try {
            actualMessages = testPageMessageManager.getMessagesById(messageIds);
        } catch (Exception e) {
            System.assert(false, 'No exceptions should be thrown.');
        }

        System.assertEquals(beforeSize, testPageMessageManager.getSize(), 'All messages should remain.');

        System.assertNotEquals(null, actualMessages, 'The actual message list should not be null.');
        System.assertEquals(messageIds.size(), actualMessages.size(), 'All requested messages should be retrieved.');
        System.assertEquals(testMessageId0, actualMessages[0].messageId, 'The first message ID should match.');
        System.assertEquals(testMessageId1, actualMessages[1].messageId, 'The second message ID should match.');
    }

    static testMethod void getSize_empty() {
        ALMPageMessages testPageMessageManager = new ALMPageMessages();

        Integer size = 0;
        Test.startTest();

            try {
                size = testPageMessageManager.getSize();
            } catch (Exception e) {
                System.assert(false, 'No exceptions should be thrown.');
            }

        Test.stopTest();

        System.assertEquals(0, size, 'There should be no messages.');
    }

    static testMethod void getSize_notEmpty() {
        ALMPageMessages testPageMessageManager = new ALMPageMessages();
        testPageMessageManager.addMessage(new PageMessage(ApexPages.Severity.ERROR, 'Content 0', false));
        testPageMessageManager.addMessage(new PageMessage(ApexPages.Severity.ERROR, 'Content 1', false));
        testPageMessageManager.addMessage(new PageMessage(ApexPages.Severity.ERROR, 'Content 2', false));

        Integer size = 0;
        Test.startTest();

            try {
                size = testPageMessageManager.getSize();
            } catch (Exception e) {
                System.assert(false, 'No exceptions should be thrown.');
            }

        Test.stopTest();

        System.assertEquals(3, size, 'There should be three messages.');
    }

    static testMethod void messages_order() {
        Long baseTime = DateTime.now().getTime();

        ALMPageMessages testPageMessageManager = new ALMPageMessages();
        Integer beforeSize = testPageMessageManager.getSize();

        PageMessage message0 = new PageMessage('Message 0', ApexPages.Severity.ERROR, 'Content 0', false);
        PageMessage message1 = new PageMessage('Message 1', ApexPages.Severity.ERROR, 'Content 1', false);
        PageMessage message2 = new PageMessage('Message 2', ApexPages.Severity.ERROR, 'Content 2', false);
        PageMessage message3 = new PageMessage('Message 3', ApexPages.Severity.ERROR, 'Content 3', false);
        PageMessage message4 = new PageMessage('Message 4', ApexPages.Severity.ERROR, 'Content 4', false);
        message1.createdTime = baseTime;
        message3.createdTime = baseTime + 1;
        message0.createdTime = baseTime + 2;
        message4.createdTime = baseTime + 3;
        message2.createdTime = baseTime + 4;

        Set<PageMessage> messages = new Set<PageMessage>{ message0, message1, message2, message3, message4 };
        testPageMessageManager.addMessages(messages);

        Test.startTest();

            List<PageMessage> actualMessages = null;
            try {
                actualMessages = testPageMessageManager.messages;
            } catch (Exception e) {
                System.assert(false, 'No exceptions should be thrown.');
            }

        Test.stopTest();

        System.assertEquals(beforeSize + messages.size(), testPageMessageManager.getSize(), 'All messages should be added.');

        System.assertNotEquals(null, actualMessages, 'The actual message list should not be null.');
        System.assertEquals(messages.size(), actualMessages.size(), 'The actual message list should contain all messages.');
        System.assertEquals(message1.messageId, actualMessages[0].messageId, 'The first message ID should match.');
        System.assertEquals(message3.messageId, actualMessages[1].messageId, 'The second message ID should match.');
        System.assertEquals(message0.messageId, actualMessages[2].messageId, 'The third message ID should match.');
        System.assertEquals(message4.messageId, actualMessages[3].messageId, 'The fourth message ID should match.');
        System.assertEquals(message2.messageId, actualMessages[4].messageId, 'The fifth message ID should match.');

    }
}