public with sharing class DeploymentServices {

    public static final String STATUS_CANCELED = 'Canceled';
    public static final String STATUS_FAILED = 'Failed';
    public static final String STATUS_IN_PROGRESS = 'InProgress';
    public static final String STATUS_NOT_STARTED = 'Not Started';
    public static final String STATUS_PENDING = 'Pending';
    public static final String STATUS_SUCCESS = 'Succeeded';

    public static final Set<String> COMPLETED_STATUSES = new Set<String>{STATUS_FAILED, STATUS_SUCCESS, STATUS_CANCELED};

    /**
    * Retrieves the status of any ongoing deployments for a build and updates
    * their data by retrieving the updated details through a callout.
    * @param buildId
    * @return Any updated deployments
    */
    public static List<Deployment_Attempt__c> updateOngoingDeployments(String buildId) {

        List<Deployment_Attempt__c> deployments = [
            SELECT UUID__c, Status__c
              FROM Deployment_Attempt__c
              WHERE Build__c = : buildId
        ];

        List<Deployment_Attempt__c> updatedDeployments = new List<Deployment_Attempt__c>();

        for (Deployment_Attempt__c deployment : deployments) {
            if (deployment.UUID__c != null && !COMPLETED_STATUSES.contains(deployment.Status__c)) {
                try {
                    updatedDeployments.add (
                        DeploymentRequest.getJobStatus(deployment.UUID__c)
                    );
                } catch(ALMException ae) {
                    ALMLogServices.error(ae, ALMLogServices.Application.SLINGSHOT);
                    System.debug(ae.getMessage());
                    throw ae;
                }
            }
        }

        if (!updatedDeployments.isEmpty()) {
            upsert updatedDeployments UUID__c;
        }

        return getDeploymentAttempts( Pluck.ids(deployments) );
    }

    public static List<Deployment_Attempt__c> getDeploymentAttempts(String buildId) {
        return [
            SELECT UUID__c, SystemModstamp, Status__c, State_Detail__c,
                Release__c, Number_Tests_Total__c, Number_Tests_Completed__c, Number_Test_Errors__c,
                Number_Components_Total__c, Number_Components_Errors__c, Number_Components_Deployed__c,
                Name, Ignore_Deployment_Warnings__c, Is_Validation__c, Id, Build__c, Start_Date__c, End_Date__c, Target_Instance__r.Name,
                Total_Code_Coverage__c, LastModifiedDate, Test_Level__c, Total_Lines__c, SF_Deployment_Id__c,
                Is_Quick_Deploy__c, Assemble_Request_Error__c, Deployment__c
            FROM Deployment_Attempt__c
            WHERE Build__c = :buildId
            ORDER BY CreatedDate DESC
        ];
    }

    public static List<Deployment_Attempt__c> getDeploymentAttempts(Set<Id> deploymentIds) {
        return [
            SELECT UUID__c, CreatedById, SystemModstamp, Status__c, State_Detail__c,
                Release__c, Number_Tests_Total__c, Number_Tests_Completed__c, Number_Test_Errors__c,
                Number_Components_Total__c, Number_Components_Errors__c, Number_Components_Deployed__c,
                Name, Ignore_Deployment_Warnings__c, Is_Validation__c, Id, Build__c, Start_Date__c, End_Date__c, Target_Instance__r.Name,
                Total_Code_Coverage__c, LastModifiedDate, Test_Level__c, Total_Lines__c,
                SF_Deployment_Id__c, Is_Quick_Deploy__c, Assemble_Request_Error__c, Deployment__c, Specified_Tests__c
            FROM Deployment_Attempt__c
            WHERE Id IN :deploymentIds
            ORDER BY CreatedDate DESC
        ];
    }

    public static List<Deployment__c> getDeploymentsByReleaseId(String releaseId) {
        return [
            SELECT  Id, Name, LastModifiedDate, Source__c, Source__r.Name, Target__c, Target__r.Name,
              Completed_Build__c, Completed_Build__r.Package_URL__c, Build__c,
              Build__r.Status__c, Build__r.Manual_Upload__c, Build__r.Package_URL__c, Build__r.Backup_URL__c,
              Build__r.Source_Repository__c, Build__r.Source_Repository__r.Name,
              Deployment_Attempt__c, Deployment_Attempt__r.End_Date__c,
              Deployment_Attempt__r.Ignore_Deployment_Warnings__c, Deployment_Attempt__r.Is_Validation__c,
              Deployment_Attempt__r.Number_Components_Deployed__c, Deployment_Attempt__r.Number_Components_Errors__c,
              Deployment_Attempt__r.Number_Components_Total__c, Deployment_Attempt__r.Number_Test_Errors__c,
              Deployment_Attempt__r.Number_Tests_Completed__c, Deployment_Attempt__r.Number_Tests_Total__c,
              Deployment_Attempt__r.Start_Date__c, Deployment_Attempt__r.State_Detail__c,
              Deployment_Attempt__r.Status__c, Deployment_Attempt__r.Total_Code_Coverage__c,
              Deployment_Attempt__r.Total_Lines__c, Deployment_Attempt__r.Total_Lines_Not_Covered__c,
              Deployment_Attempt__r.UUID__c, Deployment_Attempt__r.LastModifiedDate,
              Deployment_Attempt__r.Target_Instance__r.Name, Deployment_Attempt__r.Run_Tests__c,
              Deployment_Attempt__r.SF_Deployment_Id__c, Deployment_Attempt__r.Assemble_Request_Error__c,
              Deployment_Attempt__r.Is_Quick_Deploy__c, Deployment_Attempt__r.Deployment__c,
              Deployment_Attempt__r.Test_Level__c, Deployment_Attempt__r.Specified_Tests__c
            FROM Deployment__c
            WHERE Release__c = :releaseId
            ORDER BY CreatedDate DESC
        ];
    }

    public static Deployment__c getDeploymentByBuildId(String buildId) {
        List<Deployment__c> deployment = [
                                            SELECT  Id
                                            FROM Deployment__c
                                            WHERE Build__c = :buildId
                                         ];

        if (deployment.isEmpty()){
            return null;
        }

        return deployment[0];
    }

    /**
    * Retrieves the validation attempt for the given Deployment__c Id. This assumes that the Deployment__c made
    * a quick deploy attempt.
    * @param deploymentId   Deployment__c.Id
    * @return Deployment_Attempt__c     the validation attempt used to quick deploy
    */
    public static Deployment_Attempt__c getQuickDeployValidationAttempt(String deploymentId) {
        List<Deployment_Attempt__c> validationAttempt = [
            SELECT UUID__c, CreatedById, SystemModstamp, Status__c, State_Detail__c,
                Release__c, Number_Tests_Total__c, Number_Tests_Completed__c, Number_Test_Errors__c,
                Number_Components_Total__c, Number_Components_Errors__c, Number_Components_Deployed__c,
                Name, Is_Validation__c, Id, Build__c, Start_Date__c, End_Date__c, Target_Instance__r.Name,
                Total_Code_Coverage__c, LastModifiedDate, Test_Level__c, Total_Lines__c,
                SF_Deployment_Id__c, Is_Quick_Deploy__c, Assemble_Request_Error__c, Deployment__c, Specified_Tests__c
            FROM Deployment_Attempt__c
            WHERE Deployment__c = :deploymentId
            AND Is_Validation__c = true
            ORDER BY CreatedDate DESC
        ];

        return validationAttempt.isEmpty() ? null : validationAttempt[0];
    }

    @future(callout=true)
    public static void startAttempts(Set<Id> attemptIds) {

        List<Deployment_Attempt__c> attempts = [
            SELECT UUID__c, Status__c, Release__c, Name, Ignore_Deployment_Warnings__c, Is_Validation__c, Id, Build__c, Start_Date__c, End_Date__c,
                Test_Level__c, Target_Instance__c, Is_Quick_Deploy__c, SF_Deployment_Id__c,
                CreatedById, Specified_Tests__c
            FROM Deployment_Attempt__c
            WHERE Id IN :attemptIds
            AND Status__c = :STATUS_NOT_STARTED
            FOR UPDATE
        ];

        Map<Id, Build__c> builds = new Map<Id, Build__c>(
            BuildServices.getBuilds( Pluck.ids(Deployment_Attempt__c.Build__c, attempts) )
        );

        for (Deployment_Attempt__c attempt : attempts) {

            try {
                DeploymentRequest request = new DeploymentRequest(builds.get(attempt.Build__c), attempt);
                DeploymentRequest.DeploymentCreateResponse response = request.send();

                attempt.UUID__c = response.jobId;
                attempt.Status__c = response.result;

            } catch(ALMException ae) {
                attempt.Status__c = STATUS_FAILED;
                attempt.Assemble_Request_Error__c = System.Label.Generic_Error + ' : ' + ae.getMessage();
                ALMLogServices.error(new ALMException(ae.getMessage()), ALMLogServices.Application.SLINGSHOT);
            }
        }

        try {
            update attempts;
        } catch(DMLException de) {
            System.debug(de.getMessage());
            ALMLogServices.error(de, ALMLogServices.Application.SLINGSHOT);
        }
    }
}