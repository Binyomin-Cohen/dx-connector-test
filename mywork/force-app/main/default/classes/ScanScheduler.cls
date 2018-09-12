/**
* Scheduled class responsible for sending tool job requests
*/
global class ScanScheduler implements Schedulable, Database.AllowsCallouts {
    // Note to future developers: Ensure that this value remains as reflective as possible of the number of callouts each job execution will make.
    private static final Map<ALMJobServices.ToolType, Integer> CALLOUTS_PER_JOB = new Map<ALMJobServices.ToolType, Integer>{
        ALMJobServices.ToolType.SCAN => 3,
        ALMJobServices.ToolType.AUTOMATED_TESTING => 3
    };

    String query;

    global ScanScheduler() {

    }

    global void execute(SchedulableContext SC) {
        batchExecuteJobs(ALMJobServices.ToolType.SCAN);

        batchExecuteJobs(ALMJobServices.ToolType.AUTOMATED_TESTING);
        
        // Start VC Repo Sync jobs.
        List<ALMJob> repoSyncJobs = ALMJobServices.getJobsToRun(ALMJobServices.ToolType.VC_REPO_SYNC);

        Set<Id> repoSyncJobIds = new Set<Id>();

        DateTime now = DateTime.now();
        for(ALMJob currJob : repoSyncJobs) {
            currJob.record.Last_Queue_Time__c = now;
            repoSyncJobIds.add(currJob.getJobId());
        }

        if (!repoSyncJobIds.isEmpty()) {
            ALMJob.updateRecords(repoSyncJobs);
            VCServices.syncRepositories(repoSyncJobIds);
        }

    }

    private void batchExecuteJobs(ALMJobServices.ToolType toolType) {
        List<ALMJob> jobs = ALMJobServices.getJobsToRun(toolType);

        List<ALMJob> jobsToUpdate = new List<ALMJob>();
        Set<Id> jobIds = new Set<Id>();
        List<ALM_Application_Result__c> results = new List<ALM_Application_Result__c>();
        DateTime now = DateTime.now();
        for (ALMJob job : jobs) {
            job.record.Last_Queue_Time__c = now;
            jobIds.add(job.getJobId());
            jobsToUpdate.add(job);

            if (toolType == ALMJobServices.ToolType.SCAN) {
                results.add(
                    ALMApplicationResultServices.buildApplicationResult(
                        job.record,
                        ALMJobServices.ToolType.SCAN,
                        SCANServices.TOOL_STATUS_QUEUED
                    )
                );
            }

            // Start jobs in batches to avoid issues with the Salesforce callout limit.
            // Note to future developers: Be aware of how your changes may affect the validity of this test.
            if ((jobIds.size() + 1) >= ((Integer)(Limits.getLimitCallouts() / CALLOUTS_PER_JOB.get(toolType)))) {
                executeJobs(toolType, jobIds);
                jobIds = new Set<Id>();
            }
        }
        if (!jobIds.isEmpty()) {
            executeJobs(toolType, jobIds);
        }

        if (!jobsToUpdate.isEmpty()) {
            ALMJob.updateRecords(jobs);
        }

        if (!results.isEmpty()) {
            try {
                insert results;
            } catch (DMLException de) {
                ALMLogServices.error(de, ALMLogServices.Application.SCAN);
                return;
            }
        }
    }

    private void executeJobs(ALMJobServices.ToolType toolType, Set<Id> jobIds) {
        if (toolType == ALMJobServices.ToolType.SCAN) {
            SCANServices.sendScanJobRequest(jobIds);
        } else if (toolType == ALMJobServices.ToolType.AUTOMATED_TESTING) {
            ALMJobServices.startBUTRJobs(jobIds);
        }
    }

    global void finish(Database.BatchableContext BC) {
        
    }
}