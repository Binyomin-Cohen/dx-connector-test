/**
* Scheduled class responsible for exporting alm logs
*/
public with sharing class ALMLogExportScheduler implements Schedulable, Database.AllowsCallouts{

    public static final String SCHED_JOB_NAME = 'Scheduled ALM Log export';
    public static final String SCHED_JOB_CRON_EXP = '0 15 * * * ?';

    private static Boolean scheduleExists;

    //Default to false when running tests so the export job will not be executed
    public static Boolean ALLOW_SCHEDULE_CREATION = !Test.isRunningTest();

    public void execute(SchedulableContext SC) {
        ALMLogServices.export();
    }

    public void finish(Database.BatchableContext BC) { }

    /**
    * Ensures that a schedule exists for the SCAN batch jobs. Creates the schedules if
    * they are not found
    */
    public static void ensureScheduleExists() {
        if (ALLOW_SCHEDULE_CREATION && scheduleExists != true) {
            List<CronJobDetail> scheduledJobs = [
                SELECT Id
                FROM CronJobDetail
                WHERE Name = :SCHED_JOB_NAME
            ];

            if(scheduledJobs.isEmpty()) {
                System.schedule(
                    SCHED_JOB_NAME,
                    SCHED_JOB_CRON_EXP,
                    new ALMLogExportScheduler()
                );
            }
            scheduleExists = true;
        }
    }

}