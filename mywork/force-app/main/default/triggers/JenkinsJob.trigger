trigger JenkinsJob on Jenkins_Job__c (after update) {
    private static Boolean allow = false;
    if (trigger.isAfter && trigger.isUpdate) {
        if(!allow){
            allow =true;
            System.debug('Inside trigger'+allow); 
            JenkinsJobHandler.executeDependentJenkinsJob(Trigger.new);
         }
        
    }

}