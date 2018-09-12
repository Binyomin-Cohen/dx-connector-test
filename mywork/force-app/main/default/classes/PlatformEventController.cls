public with sharing class PlatformEventController {

    @AuraEnabled
    public static PlatformEventConfig getConfig() {
        return new PlatformEventConfig();
    }

    private class PlatformEventConfig {
        @AuraEnabled public String sessionId;
        @AuraEnabled public String namespace;

        public PlatformEventConfig() {
          this.sessionId = UserInfo.getSessionId();
          this.namespace = SObjectServices.CURRENT_NAMESPACE;
        }
    }
}
