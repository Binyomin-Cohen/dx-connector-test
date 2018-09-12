trigger CIInstance on CI_Instance__c (after update) {

    if (trigger.isAfter && trigger.isUpdate) {
    
        CIInstanceServices.autoStartValidJobs(trigger.new);
    }

}