public with sharing class ALMJob {

    public ALM_Job__c record;

    public ALMJob(ALM_Job__c record) {
        this.record = record;
    }

    public Id getJobId() {
        return (record != null ? record.Id : null);
    }

    public Boolean isScanJob() {
        return record.Tool__c == ALMJobServices.getToolName(ALMJobServices.ToolType.SCAN);
    }

    public static void insertRecords(List<ALMJob> jobs) {
        List<ALM_Job__c> records = getRecords(jobs);
        if(records.isEmpty()) {
            return;
        }
        insert records;
    }

    public static void updateRecords(List<ALMJob> jobs) {
        List<ALM_Job__c> records = getRecords(jobs);
        if(records.isEmpty()) {
            return;
        }
        update records;
    }

    public static void upsertRecords(List<ALMJob> jobs) {
        List<ALM_Job__c> records = getRecords(jobs);
        if(records.isEmpty()) {
            return;
        }
        upsert records;
    }

    public Boolean isRunnableNow() {
        return  isEnabledForToday() && 
                currentTimeIsBetweenSchedule() &&
                lastQueueTimeIsPastInterval();
    }

    public Boolean currentTimeIsBetweenSchedule() {
        return currentTimeIsBetweenSchedule(DateTime.now().hour(), DateTime.now().minute());
    }

    public Boolean currentTimeIsBetweenSchedule(Integer currentHour, Integer currentMinute) {
        return currentTimeIsBetweenSchedule(DateTime.newInstance(0, 0, 0, currentHour, currentMinute, 0));
    }

    public Boolean currentTimeIsBetweenSchedule(DateTime candidateTime) {
        DateTime startTime = DateTime.newInstance(0, 0, 0, record.Scheduled_Start_Time__c.hour(), record.Scheduled_Start_Time__c.minute(), 0);
        DateTime endTime = DateTime.newInstance(0, 0, 0, record.Scheduled_End_Time__c.hour(), record.Scheduled_End_Time__c.minute(), 0);
        candidateTime = DateTime.newInstance(0, 0, 0, candidateTime.hour(), candidateTime.minute(), 0);

        if (endTime > startTime) {
            return (startTime <= candidateTime && candidateTime <= endTime);
        } else if (endTime < startTime) {
            return (startTime <= candidateTime || candidateTime <= endTime);
        } else {
            return true;
        }
    }

    public Boolean isEnabledForToday() {
        String currDay = getCurrentDay();
        return (
            currDay == 'Mon' && record.Scheduled_On_Monday__c ||
            currDay == 'Tue' && record.Scheduled_On_Tuesday__c ||
            currDay == 'Wed' && record.Scheduled_On_Wednesday__c ||
            currDay == 'Thu' && record.Scheduled_On_Thursday__c ||
            currDay == 'Fri' && record.Scheduled_On_Friday__c ||
            currDay == 'Sat' && record.Scheduled_On_Saturday__c ||
            currDay == 'Sun' && record.Scheduled_On_Sunday__c
        );
    }

    public Boolean lastQueueTimeIsPastInterval() {
        if(record.Last_Queue_Time__c == null) {
            return true;
        }
        
        // Calculate how many hours between now and last queue time
        // and check to see if that's greater than the interval
        Long msDiff = DateTime.now().getTime() - record.Last_Queue_Time__c.getTime();
        Long hourDiff = msDiff / 1000 / 60 / 60;
        return hourDiff >= record.Interval__c;
    }

    private String getCurrentDay() {
        return DateTime.now().format('E');
    }

    private static List<ALM_Job__c> getRecords(List<ALMJob> jobs) {
        List<ALM_Job__c> records = new List<ALM_Job__c>();
        if(jobs == null || jobs.isEmpty()) {
            return records;
        }
        
        for(ALMJob currJob : jobs) {
            records.add(currJob.record);
        }
        return records;
    }
}