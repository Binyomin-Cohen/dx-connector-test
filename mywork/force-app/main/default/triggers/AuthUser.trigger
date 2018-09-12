trigger AuthUser on Auth_User__c (after update) {
    List<Auth_User__c> changedRecords = AuthUserServices.filterChangedRefreshToken(Trigger.new, Trigger.oldMap);

    if (!changedRecords.isEmpty()) {
        AuthUserServices.setLoginError(changedRecords);
    }
}