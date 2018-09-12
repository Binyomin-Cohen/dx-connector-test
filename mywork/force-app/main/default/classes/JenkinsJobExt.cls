public with sharing class JenkinsJobExt {

    /**
    * Initializes a Jenkins job run.
    * @param sc: The Jenkins_Job__c standard controller.
    */
    public JenkinsJobExt(ApexPages.StandardController sc) {
        PermissionServices.checkPagePermissions(new JenkinsJobPermissions());
    }

    @AuraEnabled
    public static String createJenkinsBuild(String jenkinsJobId, String previousSuccessfulBuildId) {
        try {
            return JenkinsServices.setupBuildRecords(jenkinsJobId, previousSuccessfulBuildId);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static PageMessage startJob(String buildId) {
        try {
            List<Jenkins_Build__c> jenkinsBuilds = [SELECT Jenkins_Job__r.Release__c, Jenkins_Job__r.Path__c,
                                                        Jenkins_Job__r.CI_Instance__c, Jenkins_Job__r.Id,
                                                        Jenkins_Job__r.Source_Repository__c, Jenkins_Job__r.Name,
                                                        Name, Status_Details__c, Package_URL__c
                                                    FROM Jenkins_Build__c WHERE Id = :buildId];

            if (jenkinsBuilds.isEmpty()) {
                return new PageMessage(ApexPages.Severity.ERROR,
                                System.Label.Failure_Starting_Jenkins_Job + ' Unable to find build record.');
            }

	        Jenkins_Build__c jBuild = jenkinsBuilds[0];
            PageMessage response;
            if (String.isNotBlank(jBuild.Package_URL__C)) {
                JenkinsServices.deployBuildPackage(jBuild.Id);
                response = makeJobStartedMessage(jBuild.Jenkins_Job__r.Name, jBuild.Name);
            } else if (jBuild.Jenkins_Job__r.Source_Repository__c != null) {
                jBuild = JenkinsServices.startAssemblerJob(jBuild.Id);
                response = (jBuild.Status__c == JenkinsServices.JENKINS_SF_BUILD_IN_PROGRESS_STATUS) ?
                                makeJobStartedMessage(jBuild.Jenkins_Job__r.Name, jBuild.Name) :
                                new PageMessage(ApexPages.Severity.ERROR, System.Label.Failure_Starting_Jenkins_Job
                                                                         + ' ' + jBuild.Status_Details__c);
            } else {
                response = new PageMessage(ApexPages.Severity.ERROR, System.Label.Jenkins_Build_Error_No_Repo_Or_Reused_Build);
            }
            return response;

        } catch (Exception e) {
            JenkinsServices.updateJenkinsBuildStatus(new Jenkins_Build__c(Id=buildId),
                                                     JenkinsServices.JENKINS_BUILD_FAILURE_STATUS);
            return new PageMessage(ApexPages.Severity.ERROR,
                            System.Label.Failure_Starting_Jenkins_Job + '  ' + e.getMessage());
        }
    }

    private static PageMessage makeJobStartedMessage(String jobName, String jenkinsBuildName) {
        String message = 'Jenkins job \'' + jobName + '\' has started build ' + jenkinsBuildName + '.';
        return new PageMessage(ApexPages.Severity.INFO, message);
    }

    /**
    * Grabs all the successful Jenkins builds from the given Release.
    * @param releaseId: Id of the Release__c record
    * @return List<JenkinsBuild>: A list of JenkinsBuild objects.
    */
    @AuraEnabled
    public static List<JenkinsBuild> getExistingSuccessfulBuildsForRelease(String releaseId) {
        List<Jenkins_Build__c> successfulJenkinsBuilds =
            [SELECT Id, Name, CI_Instance__r.Name, Jenkins_Job__c, Jenkins_Job__r.Name, Jenkins_Job__r.Release__c,
                    Package_URL__c
             FROM Jenkins_Build__c
             WHERE Status__c=:'SUCCESS' AND Jenkins_Job__r.Release__c=:releaseId AND Package_URL__c != null
             ORDER BY CreatedDate DESC];

        List<JenkinsBuild> successfulBuilds = new List<JenkinsBuild>();
        for (Jenkins_Build__c build : successfulJenkinsBuilds) {
            successfulBuilds.add(new JenkinsBuild(build));
        }

        return successfulBuilds;
    }

    @AuraEnabled
    public static List<BuildRuleCriterion> getBuildRuleCriteria(String jenkinsJobId) {
        Jenkins_Job__c existingJob = JenkinsServices.getExistingJob(jenkinsJobId);

        Map<String, Schema.SObjectField> fieldMap = CI_Instance__c.SObjectType.getDescribe().fields.getMap();

        Map<String, Boolean> criteriaEvaluation = JenkinsServices.getBuildRuleCriteriaEvaluations(existingJob);
        List<BuildRuleCriterion> criteria = new List<BuildRuleCriterion>();
        List<String> sortedCriteriaValues = new List<String>(criteriaEvaluation.keySet());
        sortedCriteriaValues.sort();
        for (String fieldName : sortedCriteriaValues) {
            if (fieldMap.containsKey(fieldName)) {
                String label = fieldMap.get(fieldName).getDescribe().getLabel();
                criteria.add( new BuildRuleCriterion(label + ' (' + fieldName + ')', criteriaEvaluation.get(fieldName)) );
            }

        }

        return criteria;
    }

    public class BuildRuleCriterion {
        @AuraEnabled
        public String label;
        @AuraEnabled
        public Boolean value;

        public BuildRuleCriterion(String label, Boolean value) {
            this.label = label;
            this.value = value;
        }
    }

    public class JenkinsBuild {
        @AuraEnabled
        public String id;
        @AuraEnabled
        public String name;
        @AuraEnabled
        public String ciInstanceName;
        @AuraEnabled
        public String jobName;
        public String releaseId;

        public JenkinsBuild(Jenkins_Build__c jenkinsBuild) {
            id = jenkinsBuild.Id;
            name = jenkinsBuild.Name;
            ciInstanceName = jenkinsBuild.CI_Instance__r.Name;
            jobName = jenkinsBuild.Jenkins_Job__r.Name;
            releaseId = jenkinsBuild.Jenkins_Job__r.Release__c;
        }
    }
}
