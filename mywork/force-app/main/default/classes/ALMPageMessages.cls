public class ALMPageMessages {
    private Map<String, PageMessage> messageMap;
    public List<PageMessage> messages {
        get {
            List<PageMessage> sortedMessages = messageMap.values();
            sortedMessages.sort();
            
            return sortedMessages;
        }
        private set;
    }
    
    public ALMPageMessages() {
        messageMap = new Map<String, PageMessage>();
    }

    public void addMessage(PageMessage message) {
        if (message == null) {
            return;
        }

        if (message.messageId == null) {
            message.messageId = String.valueOf(Crypto.getRandomInteger());
        }
        messageMap.put(message.messageId, message);
    }

    public void addMessages(Set<PageMessage> messages) {
        for (PageMessage message : messages) {
            addMessage(message);
        }
    }

    public void removeMessageById(String messageId) {
        messageMap.remove(messageId);
    }

    public void removeMessagesById(Set<String> messageIds) {
        for (String messageId : messageIds) {
            removeMessageById(messageId);
        }
    }

    public PageMessage getMessageById(String messageId) {
        return messageMap.get(messageId);
    }

    public List<PageMessage> getMessagesById(List<String> messageIds) {
        List<PageMessage> messages = new List<PageMessage>();

        for (String messageId : messageIds) {
            messages.add(getMessageById(messageId));
        }

        return messages;
    }

    public Integer getSize() {
        return messages.size();
    }
}