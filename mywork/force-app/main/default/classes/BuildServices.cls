public with sharing class BuildServices {
    public static final String STATUS_NOT_STARTED = 'Not Started';
    public static final String STATUS_IN_PROGRESS = 'In Progress';
    public static final String STATUS_PENDING = 'Pending';
    public static final String STATUS_SUCCESS = 'Success';
    public static final String STATUS_FAILURE = 'Failed';
    public static final String STATUS_JENKINS_FAILURE_HIT_FUTURE_LIMIT =
        'Maximum number of concurrent deployable builds (50) exceeded.';
    public static final Set<String> COMPLETE_STATUSES = new Set<String> { STATUS_SUCCESS, STATUS_FAILURE };
    public static final Set<String> STARTED_STATUSES = new Set<String> { STATUS_PENDING, STATUS_IN_PROGRESS };

    /**
    * Deploy any newly finished builds
    *  @param  oldBuilds   Should be trigger.oldMap
    *  @param  newBuilds   Should be trigger.new
    */
    public static void deployFinishedBuilds(Map<Id, Build__c> oldBuilds, List<Build__c> newBuilds) {
        List<Build__c> deployerBuilds = new List<Build__c>();
        List<Build__c> jenkinsBuilds = new List<Build__c>();

        // at this point we don't have the requeried builds
        for(Build__c build : getNewlyFinishedBuilds(oldBuilds, newBuilds)) {
            if (build.Jenkins_Build__c != null) {
                jenkinsBuilds.add(build);
            } else {
                deployerBuilds.add(build);
            }
        }

        if (!deployerBuilds.isEmpty()) {
            BuildServices.updateDeploymentWithCompletedBuild(deployerBuilds);
            Set<Id> deploymentAttemptsToStart = BuildServices.getDeploymentAttemptsToStart(deployerBuilds);

            if (!deploymentAttemptsToStart.isEmpty()) {
               DeploymentServices.startAttempts(deploymentAttemptsToStart);
            }
        }

        if (!jenkinsBuilds.isEmpty()) {
            deployJenkinsBuilds(jenkinsBuilds);
        }
    }

    private static void deployJenkinsBuilds(List<Build__c> builds) {
        List<Build__c> buildsWithErrorsAndJobInfo = [SELECT Id, Jenkins_Build__c, Package_URL__c,
                                                         Jenkins_Build__r.Jenkins_Job__r.Ignore_Build_Errors__c,
                                                        (SELECT Id FROM ALM_Errors__r)
                                                     FROM Build__c
                                                     WHERE Id IN :Pluck.ids(builds)
                                                      AND Jenkins_Build__r.Status__c != :JenkinsServices.JENKINS_BUILD_FAILURE_STATUS];

        List<Jenkins_Build__c> undeployableJenkinsBuilds = new List<Jenkins_Build__c>();
        for (Build__c build : buildsWithErrorsAndJobInfo) {
            Boolean ignoreErrors = build.Jenkins_Build__r.Jenkins_Job__r.Ignore_Build_Errors__c;

            Jenkins_Build__c jBuild = new Jenkins_Build__c(Id=build.Jenkins_Build__c);
            jBuild.Package_URL__c = build.Package_URL__c;
            if (build.ALM_Errors__r.size() > 0 && !ignoreErrors) {
                jBuild.Status__c=JenkinsServices.JENKINS_BUILD_FAILURE_STATUS;
                jBuild.Status_Details__c=System.Label.Jenkins_Build_Assembler_Failure_Errors_Not_Ignored;
                undeployableJenkinsBuilds.add(jBuild);
            } else if (Limits.getLimitFutureCalls() <= 0) {
                jBuild.Status__c=JenkinsServices.JENKINS_BUILD_FAILURE_STATUS;
                jBuild.Status_Details__c=STATUS_JENKINS_FAILURE_HIT_FUTURE_LIMIT;
                undeployableJenkinsBuilds.add(jBuild);
            } else {
                String statusDetails = build.ALM_Errors__r.size() > 0 ?
                    System.Label.Jenkins_Build_Assembler_Warning_Errors_Ignored : '';
                //TODO: bulkify
                JenkinsServices.updateJenkinsBuildStatuses(jBuild, jBuild.Status__c, statusDetails);
                JenkinsServices.deployBuildPackage(jBuild.Id);
            }
        }

        if (!undeployableJenkinsBuilds.isEmpty()) {
            try {
                SObjectServices.updateSObjectsAllowingPartialSuccess(undeployableJenkinsBuilds);
            } catch (ALMException e) {
                ALMLogServices.error(e, ALMLogServices.Application.JENKINS);
            }
        }
    }

    /**
    * Gets the Build__c record from the database based on the buildId passed in.
    * @param String buildId
    * @throws Exception when trying to instantiate a bad Id for the Set of Ids
    */
    public static Build__c getBuild(String buildId) {
        List<Build__c> builds = getBuilds(new Set<Id>{buildId});

        if (builds.isEmpty()){
            return null;
        }

        return builds[0];
    }

    /**
    * Gets Build__c records from the database based on the set of build ids passed in.
    * @param Set<Id> buildIds
    * @throws Exception if buildIds has a bad Id in it
    */
    public static List<Build__c> getBuilds(Set<Id> buildIds) {
         return [
            SELECT Id, Status__c, UUID__c, Release__c, Package_URL__c, Manual_Upload__c,
                 Source_Repository__c, Source_Repository_Location__c, Jenkins_Build__c,
                 Is_Manual_Package_Parsed__c, Manual_Package_Parse_Failure_Reason__c,
                    (Select Id, Assemble_Request_Error__c from Deployment_Attempts__r Order By CreatedDate DESC LIMIT 1)
            FROM Build__c
            WHERE Id IN :buildIds
        ];
    }

    public static List<Build__c> getNewlyFinishedBuilds(Map<Id, Build__c> oldBuilds, List<Build__c> builds) {
        List<Build__c> deployerBuilds = new List<Build__c>();
        for(Build__c build : builds) {
            Build__c oldBuild = oldBuilds.get(build.Id);
            if (oldBuild.Status__c != build.Status__c && COMPLETE_STATUSES.contains(build.Status__c)) {
                deployerBuilds.add(build);
            }
        }

        return deployerBuilds;
    }

    /**
    *   Updates the Completed_Build__c reference on any related deployments to the passed in Builds
    *   @param  builds      The builds that are completed. SObjects should reference records from trigger.new
    *                        in order for any errors to be added properly
    */
    public static void updateDeploymentWithCompletedBuild(List<Build__c> builds) {
        List<Deployment__c> deploymentsToUpdate = [
            SELECT Id, Build__c, Completed_Build__c
            FROM Deployment__c
             WHERE Build__c IN :builds
        ];

        for (Deployment__c deployment : deploymentsToUpdate) {
        	deployment.Completed_Build__c = deployment.Build__c;
        }

        if (!deploymentsToUpdate.isEmpty()) {
        	try {
            	update deploymentsToUpdate;
        	} catch(DmlException de) {
        		for (Integer i = 0; i < de.getNumDml(); i++) {
	                Map<Id, Build__c> buildMap = new Map<Id, Build__c>(builds);
	        		Integer failedIndex = de.getDmlIndex(i);
	        		String failedMessage = de.getDmlMessage(i);
	        		buildMap.get( deploymentsToUpdate[failedIndex].Build__c ).addError( failedMessage );
        		}
        	}
        }
    }

    /**
    * Filters builds that have a Deployment_Attempt__c that is Not Started and are currently
    *  referenced by a Deployment__c
    * @return   Set<Id>  Deployment_Attempt__c ids
    */
    public static Set<Id> getDeploymentAttemptsToStart(List<Build__c> builds) {
        Set<Id> attemptsToStart = new Set<Id>();

        List<Deployment_Attempt__c> attemptsWithDeployments = [
            SELECT Id, Status__c,
                (SELECT Id From Deployments__r)
            FROM Deployment_Attempt__c
            WHERE Build__c IN :builds
            AND Status__c = :DeploymentServices.STATUS_NOT_STARTED
        ];

        for (Deployment_Attempt__c attempt : attemptsWithDeployments) {
        	if (!attempt.Deployments__r.isEmpty()) {
	        	attemptsToStart.add(attempt.Id);
        	}
        }

        return attemptsToStart;
    }

    /**
    * Retrieves the most recently created build package for the provided build. Target backups are excluded
    * @param  buildId      The parent ID of the attachment
    * @return   Attachment for the build package
    */
    public static Attachment getLatestBuildPackage(Id buildId) {
        List<Attachment> packageAttachments = [SELECT Id, Name, ParentId, Body
                                               FROM Attachment WHERE ParentId =: buildId
                                                    AND Name LIKE 'build-%.zip'
                                                    AND (NOT Name LIKE '%target%')
                                               ORDER BY Name DESC LIMIT 1];
        if (packageAttachments.size() == 0) {
            return null;
        } else {
            return packageAttachments[0];
        }
    }
}
