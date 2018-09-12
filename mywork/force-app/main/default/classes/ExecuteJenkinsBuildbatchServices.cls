/**
* @author Vivek
* @date 8th Sep, 2017
*
* @group <Salesforce Garage>
*
* @description Class to check if Jenkins Batch is Running, Scheduled or in progress 
*/
public with sharing class ExecuteJenkinsBuildbatchServices {
    public static final String SCHEDULED_STATUS = 'Scheduled';
    @TestVisible private final static String RUNNING_BATCH = 'Processing';
    @TestVisible private final static String QUEUED_BATCH = 'Queued';
    @TestVisible private final static String PREPARING_BATCH = 'Preparing';
    public final static List<String> STARTING_CATEGORY = new List<String>{QUEUED_BATCH, PREPARING_BATCH};
    
    /**
   * @description Method to Check for Status of Batch Job
   * @return Boolean
   */
    public static boolean isMonitorBatchScheduledOrRunning() {
        Boolean found = false;

        //First we check to see if the job is scheduled
        String cronQuery =    'SELECT Id'
                + ' FROM CronTrigger WHERE NextFireTime <> null'
                + ' AND CronJobDetail.Name = \''+JenkinsBuildBatchJob.BATCH_JOB_TITLE+'\''
                + ' LIMIT 1';
        List<CronTrigger> cjobs = Database.query(cronQuery);

        if (!cjobs.isEmpty()) {
            found = true;
        }
        else
        {
            //Then we check to see if it is running or queued
            String query =  'SELECT Id'
                    + ' FROM AsyncApexJob'
                    + ' WHERE (JobType = \'BatchApex\')'
                    + ' AND ApexClass.Name = \'JenkinsBuildBatchJob\''
                    + ' AND (Status in ' + BluewolfDevUtils.flattenListForQuery(STARTING_CATEGORY)
                    + ' OR Status in '+ BluewolfDevUtils.flattenListForQuery(new List<String>{ RUNNING_BATCH }) + ')'
                    + ' LIMIT 1';

            List<AsyncApexJob> inProgressJobs = Database.query(query);

            if (!inProgressJobs.isEmpty()) {
                found = true;
            }
        }

        return found;
    }
}