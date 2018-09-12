public with sharing class JenkinsJobHandler{
    
    public static final String JENKINS_JOB_DEFAULT_STATUS = 'Pending';
    public static final String JENKINS_JOB_SUCCESS_STATUS = 'Success';   
    
    /**
    * Check any dependent jenkins jobs which can be triggered automatically and then start jobs
    *  @param  jenkinsJobs Should be trigger.new
    */    
     public static void executeDependentJenkinsJob(List<Jenkins_Job__c> jenkinsJobs){
        Set<Id> depJobIds = new Set<Id>();
        List<Jenkins_Job__c> depJobs = new List<Jenkins_job__c>();
        for (Jenkins_Job__c jJob: jenkinsJobs) {
               Jenkins_Job__c oldJob = (Jenkins_Job__c) Trigger.oldMap.get(jJob.ID);
               if(JENKINS_JOB_DEFAULT_STATUS.equalsIgnorecase(oldJob.Last_Build_Status__c)
                       && JENKINS_JOB_SUCCESS_STATUS.equalsIgnorecase(jJob.Last_Build_Status__c)) {
                       if(jJob.Dependent_Jenkins_Job__c != null){
                           depJobIds.add(jJob.Dependent_Jenkins_Job__c);
                       }                      
                }
               
        }
        if(!depJobIds.isEmpty()){
            depJobs = [SELECT Build_Rule__r.Boolean_Criteria__c , Build_Rule__c, CI_Instance__c FROM Jenkins_Job__c WHERE Id IN : depJobIds AND Trigger_Job_Automatically__c = true]; 
            for(Jenkins_Job__c depJenkinsJob : depJobs ){
                if(depJenkinsJob  != null){
                    CIInstanceservices.executeValidJob((Jenkins_Job__c)depJenkinsJob);
                }
            }
        }        
       
    } 
    
 
}