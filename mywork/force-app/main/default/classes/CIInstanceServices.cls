public with sharing class CIInstanceServices {

    public static final String CRITERIA_DELIMITER = ';';
    public static final String JENKINS_JOB_DEFAULT_STATUS = 'Pending';
    public static final String JENKINS_BUILD_FAILURE_STATUS = 'FAILURE';

    /**
    * Check the checkbox values and start jobs
    *  @param  newBuilds   Should be trigger.new
    */
    public static void autoStartValidJobs(List<CI_Instance__c> newBuilds) {

        for(CI_Instance__c newBuild : newBuilds){
            SObject oldCiInstance = Trigger.oldMap.get(newBuild.ID);
            List<Jenkins_Job__c> lstJenkinsJobs = getJenkinsJobs(newBuild.Id);
            for(Jenkins_Job__c jJob : lstJenkinsJobs){
                if(buildCriteriaChangedFromInvalidToValid(newBuild, (CI_Instance__c)oldCiInstance, jJob)){
                    //TODO For now Execute first matching Job and end assumption is only one job matching criteria will be available
                    executeValidJob(jJob);
                    break;
                }
            }
        }
    }


    /**
    * Gets all child jobs for a CI Instance record.
    */
    private static List<Jenkins_Job__c> getJenkinsJobs(String ciInstanceId){
        List<Jenkins_Job__c> lstchildJobs = [SELECT Build_Rule__r.Boolean_Criteria__c , Build_Rule__c, CI_Instance__c FROM Jenkins_Job__c WHERE CI_Instance__c = :ciInstanceId AND Trigger_Job_Automatically__c = true];
        return lstchildJobs;
    }


    /**
    *  Create Jenkins build object
    *  @param  jenkinsJobId
    *  @return buildId
    */
    private static String createJenkinsBuild(String jenkinsJobId) {
        List<Jenkins_Job__c> existingJobs = [SELECT CI_Instance__c FROM Jenkins_Job__c WHERE Id = :jenkinsJobId];

        if (!existingJobs.isEmpty()) {
            try {
                Jenkins_Build__c build = new Jenkins_Build__c(Jenkins_Job__c=jenkinsJobId, CI_Instance__c = existingJobs[0].CI_Instance__c,Status__c=JENKINS_JOB_DEFAULT_STATUS);
                insert build;
                return build.Id;
            } catch (DMLException de) {
                ALMLogServices.error(de,ALMLogServices.Application.JENKINS);
                return null;
            }
         }else{
             return null;
         }
    }

    /**
     *  Pass the jenkins buildId to start the jenkins job
     *  @param  buildId
     */
    @future (callout=true)
    private static void startJobAsync(String jenkinsBuildId) {
        Jenkins_Build__c jenkinsBuild;
        try {
            List<Jenkins_Build__c> jenkinsBuilds = [SELECT Jenkins_Job__r.Release__c, Jenkins_Job__r.CI_Instance__c, Jenkins_Job__r.Id, Name  FROM Jenkins_Build__c WHERE Id = :jenkinsBuildId];
            if (!jenkinsBuilds.isEmpty()) {
                jenkinsBuild = jenkinsBuilds[0];
                JenkinsServices.startAssemblerJob(jenkinsBuild.Id);
            }
        } catch (Exception e) {
            JenkinsServices.updateJenkinsBuildStatus(jenkinsBuild, JENKINS_BUILD_FAILURE_STATUS);
            ALMLogServices.error(e, ALMLogServices.Application.JENKINS);
        }
    }


    /**
    * Check the jenkins jobs build rule criteria with CI instance checkbox checked
    *  @param  jenkinsJob , ciInstanceId
    */
    public static Boolean executeValidJob(Jenkins_Job__c jJob){
        Boolean isValid = false;
        if (JenkinsServices.evaluateBuildRule(jJob))
        {
            Id jBuildId = JenkinsServices.setupBuildRecords(jJob.Id, '');
            if(LimitServices.getRemainingFutureCallsAvailable() > 0) {
                startJobAsync(jBuildId);
                isValid = true;
            } else {
                ALMLogServices.error(new ALMException('Unable to execute jenkins job since no more future calls are available'),ALMLogServices.Application.JENKINS);
                isValid = false;
            }
        }
        return isValid;
    }

    /**
    * Gets all Checkbox fields on CI_Instance__c.
    */
    private static Boolean buildCriteriaChangedFromInvalidToValid(CI_Instance__c newObject, CI_Instance__c oldObject, Jenkins_Job__c job) {
        Set<String> existingCriteria = JenkinsServices.getExistingBuildRuleCriteria(job);
        if (existingCriteria.isEmpty()) {
            //TODO: If trigger job automatically is checked and no build criteria Can we make to return true?
            return false;
        }

        Boolean isOldValid = true;
        Boolean isNewValid = true;
        for (String criteria : existingCriteria) {
            try {
                isOldValid  = (isOldValid && (Boolean)oldObject.get(criteria));
                isNewValid  = (isNewValid && (Boolean)newObject.get(criteria));
            } catch (Exception ex) {
                //skip any invalid fields
                ALMLogServices.error(ex, ALMLogServices.Application.JENKINS);
            }
        }
        return (!isOldValid && isNewValid );
    }
}
