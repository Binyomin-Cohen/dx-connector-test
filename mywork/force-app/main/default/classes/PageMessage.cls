public with sharing class PageMessage implements Comparable {

    public enum Severity {SUCCESS}

    @AuraEnabled
    public String messageType {get; set;}
    @AuraEnabled
    public String message {get; set;}
    public String messageId {get; set;}
    public Boolean showCloseButton {get; set;}

    @TestVisible private Long createdTime {get; set;}

    public PageMessage(ApexPages.Severity severity, String message) {
        if (severity == ApexPages.Severity.FATAL || severity == ApexPages.Severity.ERROR) {
            this.messageType = ApexPages.Severity.ERROR.name().toLowerCase();
        } else {
            this.messageType = severity.name().toLowerCase();
        }
        this.message = message;
        this.messageId = null;
        this.showCloseButton = true;
        this.createdTime = DateTime.now().getTime();
    }

    public PageMessage(Severity severity, String message) {
        this.messageType = severity.name().toLowerCase();
        this.message = message;
        this.messageId = null;
        this.showCloseButton = true;
        this.createdTime = DateTime.now().getTime();
    }

    public PageMessage(String messageId, ApexPages.Severity severity, String message, Boolean showCloseButton) {
        this(severity, message);
        this.messageId = messageId;
        this.showCloseButton = showCloseButton;
    }

    public PageMessage(ApexPages.Severity severity, String message, Boolean showCloseButton) {
        this(null, severity, message, showCloseButton);
    }

    public Integer compareTo(Object otherObject) {
        PageMessage otherMessage = (PageMessage)otherObject;

        if (this.createdTime == null && otherMessage.createdTime != null) {
            return -1;
        } else if (this.createdTime != null && otherMessage.createdTime == null) {
            return 1;
        } else if (this.createdTime == null && otherMessage.createdTime == null) {
            return 0;
        }

        Long result = this.createdTime - otherMessage.createdTime;
        if (result < 0) {
            return -1;
        } else if (result > 0) {
            return 1;
        } else {
            return 0;
        }
    }
}