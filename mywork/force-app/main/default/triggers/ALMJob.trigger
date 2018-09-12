trigger ALMJob on ALM_Job__c (before update) {
    if (trigger.isBefore && trigger.isUpdate) {
        ALMApplicationResultServices.updateMailToOnNonCompletedResults(trigger.new, trigger.oldMap);
    }
}