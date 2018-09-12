trigger Backlog on Custom_Backlog__c (before insert, before update) {
    CustomBacklogServices.addErrorsToDuplicateUniversalBacklogs(Trigger.new);
}