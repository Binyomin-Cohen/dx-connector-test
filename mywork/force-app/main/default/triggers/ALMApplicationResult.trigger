trigger ALMApplicationResult on ALM_Application_Result__c (before insert, after insert, after update) {

    if (trigger.isBefore && trigger.isInsert) {
        ALMApplicationResultServices.copyMailToField(trigger.new);
    }
    
    if (trigger.isAfter && trigger.isInsert) {
        try {
            ApplicationResultCleanerServices.scheduleCleaning();
        } catch (Exception e) {
            ALMLogServices.error(e, ALMLogServices.Application.APPLICATION_RESULT_CLEANER);
        }
    } else if (trigger.isAfter && trigger.isUpdate && !ALMApplicationResultServices.TRIGGER_HAS_RUN) {
        ALMApplicationResultServices.TRIGGER_HAS_RUN = true;
        Map<String, List<ALM_Application_Result__c>> successAndCompletedJobs =
            ALMApplicationResultServices.filterCompletedSCANJobs(trigger.new, trigger.oldMap);
        List<ALM_Application_Result__c> completedSCANJobs =
            successAndCompletedJobs.get(ALMApplicationResultServices.SUCCESS_RESULT_MAP_IDENTIFIER);
        List<ALM_Application_Result__c> allCompletedSCANJobs =
            successAndCompletedJobs.get(ALMApplicationResultServices.COMPLETED_RESULT_MAP_IDENTIFIER);

        if (!allCompletedSCANJobs.IsEmpty()) {
            //Requery for the instance name of the result
            List<ALM_Application_Result__c> updatedResults = [SELECT Id, Instance__r.Name,
                                                                     Instance__r.Id, Run_Time__c,
                                                                     Result__c
                                                              FROM ALM_Application_Result__c
                                                              WHERE Id in: allCompletedSCANJobs];

            try {
                Map<Id, ALMApplicationResultServices.InstanceWithLatestAndSuccessfulRunTime> instanceToTimesCache =
                    InstanceServices.populateCacheWithInstanceRunTimes(updatedResults);

                if (instanceToTimesCache != null && !instanceToTimesCache.isEmpty()) {
                    State.store(new ALMApplicationResultServices.ResultState(instanceToTimesCache));
                }
            } catch ( Exception e ) {
                ALMLogServices.error( e, ALMLogServices.Application.SCAN );
            }

            if (LimitServices.getRemainingFutureCallsAvailable() > 0 && !System.isFuture()) {
                ComponentDocServices.refreshRecentlyModifiedComponentsCache();
            }
        }

        for (String instanceId : Pluck.strings(ALM_Application_Result__c.Instance__c, completedSCANJobs)) {

            //We only want to update cache when these records come in 1 at a time, but we can cache as many
            //profile templates as jobs that come in if there are future calls remaining
            if (LimitServices.getRemainingFutureCallsAvailable() > 0 && !System.isFuture()) {
                ProfileServices.refreshProfileTemplateCacheInFuture(instanceId);
            }
        }
    }
}