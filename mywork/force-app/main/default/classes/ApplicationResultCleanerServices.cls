public with sharing class ApplicationResultCleanerServices {
    @TestVisible private static final Integer SCHEDULE_DELAY_DEFAULT = 1;
    private static final List<String> JOB_IN_PROGRESS_STATUSES = new List<String>{
        'Holding',
        'Queued',
        'Preparing',
        'Processing'
    };
    private static final Map<ALMJobServices.ToolType, String> JOB_TYPE_TO_CLEANER_CLASS_NAME = new Map<ALMJobServices.ToolType, String>{
        ALMJobServices.ToolType.SCAN => 'InstanceApplicationResultCleaner',
        ALMJobServices.ToolType.AUTOMATED_TESTING => 'InstanceApplicationResultCleaner',
        ALMJobServices.ToolType.VC_REPO_SYNC => 'VCRepoSyncApplicationResultCleaner'
    };
    private static final Map<ALMJobServices.ToolType, String> JOB_TYPE_TO_CLEANER_NAME = new Map<ALMJobServices.ToolType, String>{
        ALMJobServices.ToolType.SCAN => InstanceApplicationResultCleaner.CLEANER_NAME,
        ALMJobServices.ToolType.AUTOMATED_TESTING => InstanceApplicationResultCleaner.CLEANER_NAME,
        ALMJobServices.ToolType.VC_REPO_SYNC => VCRepoSyncApplicationResultCleaner.CLEANER_NAME
    };

    /**
    * Schedules application result cleaner batch jobs for all job types, if they are not already running.
    * @throws AsyncException
    */
    public static void scheduleCleaning() {
        scheduleCleaning(JOB_TYPE_TO_CLEANER_CLASS_NAME.keySet(), SCHEDULE_DELAY_DEFAULT);
    }

    /**
    * Schedules application result cleaner batch jobs for the given job types, if they are not already running.
    * @throws AsyncException
    */
    public static void scheduleCleaning(Set<ALMJobServices.ToolType> toolTypes) {
        scheduleCleaning(toolTypes, SCHEDULE_DELAY_DEFAULT);
    }

    /**
    * Builds a cron expression based on minutes in the future
    * @param minutesFromNow - The delay (in minutes).
    */
    public static String buildCronExpressionFromMinutesInTheFuture(Integer minutesFromNow) {
        if (minutesFromNow == null) {
            minutesFromNow = SCHEDULE_DELAY_DEFAULT;
        }

        DateTime scheduledTime = DateTime.now().addMinutes(minutesFromNow);

        String cronExpression =
            scheduledTime.second() + ' ' +
            scheduledTime.minute() + ' ' +
            scheduledTime.hour() + ' ' +
            scheduledTime.day() + ' ' +
            scheduledTime.month() + ' ? ' +
            scheduledTime.year();

        return cronExpression;
    }

    /**
    * Schedules application result cleaner batch jobs for the given job types, if they are not already running.
    * @param minutesFromNow - The delay (in minutes) for the initiation of the scheduled job.
    * @throws AsyncException
    */
    public static void scheduleCleaning(Set<ALMJobServices.ToolType> toolTypes, Integer minutesFromNow) {
        String cronExpression = buildCronExpressionFromMinutesInTheFuture(minutesFromNow);

        Set<ApplicationResultCleaner> cleaners = new Set<ApplicationResultCleaner>();
        for (ALMJobServices.ToolType toolType : toolTypes) {
            if (!isCleanerRunning(toolType)) {
                cleaners.add(createNewToolCleaner(toolType));
            }
        }

        for (ApplicationResultCleaner cleaner : cleaners) {
            System.schedule(cleaner.getCleanerName(), cronExpression, (Schedulable)cleaner);
        }
    }

    /**
    * Immediately executes the application result cleaner batch job, if it is not already running.
    */
    public static void executeCleaning(Set<ALMJobServices.ToolType> toolTypes) {
        Set<ApplicationResultCleaner> cleaners = new Set<ApplicationResultCleaner>();
        for (ALMJobServices.ToolType toolType : toolTypes) {
            if (!isCleanerRunning(toolType)) {
                cleaners.add(createNewToolCleaner(toolType));
            }
        }

        for (ApplicationResultCleaner cleaner : cleaners) {
            Database.executeBatch((Database.Batchable<SObject>)cleaner);
        }
    }

    /**
    * Determines whether or not the application result cleaner batch job is already running.
    * @return - Whether or not the application result cleaner batch job is already running.
    */
    public static Boolean isCleanerRunning(ALMJobServices.ToolType toolType) {
        String cleanerName = JOB_TYPE_TO_CLEANER_NAME.get(toolType);
        String className = JOB_TYPE_TO_CLEANER_CLASS_NAME.get(toolType);

        return isCleanerRunning(className, cleanerName);
    }

    /**
    * Determines whether or not the application result cleaner batch job is already running.
    * @param - className - the name of the apex class that is scheduled
    * @param - cleanerName - the name of the job that is scheduled
    * @return - Whether or not the application result cleaner batch job is already running.
    */
    public static Boolean isCleanerRunning(String className, String cleanerName) {
        List<CronTrigger> scheduledJobs = [
            SELECT Id
            FROM CronTrigger
            WHERE NextFireTime != null AND CronJobDetail.Name = :cleanerName
            LIMIT 1
        ];

        if (!scheduledJobs.isEmpty()) {
            return true;
        }

        List<AsyncApexJob> inProgressJobs = [
            SELECT Id
            FROM AsyncApexJob
            WHERE JobType = 'BatchApex' AND ApexClass.Name = :className AND Status IN :JOB_IN_PROGRESS_STATUSES
            LIMIT 1
        ];

        return !inProgressJobs.isEmpty();
    }

    /**
    * Determines the retention datetime boundary, denoting a minimum age for results being cleaned by the cleaner.
    * @return - The retention datetime boundary, denoting a minimum age for results being cleaned by the cleaner.
    */
    public static DateTime getRetentionBoundary() {
        DateTime retentionBoundary = null;
        if (ALMSettings__c.getInstance().Sync_History_Retention__c != null && ALMSettings__c.getInstance().Sync_History_Retention__c > 0) {
            retentionBoundary = DateTime.now().addDays(-1 * Integer.valueOf(ALMSettings__c.getInstance().Sync_History_Retention__c));
        }

        return retentionBoundary;
    }

    private static ApplicationResultCleaner createNewToolCleaner(ALMJobServices.ToolType toolType) {
        return (ApplicationResultCleaner)Type.forName(JOB_TYPE_TO_CLEANER_CLASS_NAME.get(toolType)).newInstance();
    }
}