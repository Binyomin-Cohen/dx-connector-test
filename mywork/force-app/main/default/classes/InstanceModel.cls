public with sharing class InstanceModel implements Comparable {
    public static final Integer DEFAULT_SCAN_INTERVAL = 4;
    public static final Integer DEFAULT_BUTR_INTERVAL = 4;
    public static final DateTime DEFAULT_SCAN_START_TIME = DateTime.newInstance(Date.today(), Time.newInstance(9,0,0,0));
    public static final DateTime DEFAULT_SCAN_END_TIME = DEFAULT_SCAN_START_TIME.addHours(8);
    public static final DateTime DEFAULT_BUTR_START_TIME = DateTime.newInstance(Date.today(), Time.newInstance(1,0,0,0));
    public static final DateTime DEFAULT_BUTR_END_TIME = DEFAULT_BUTR_START_TIME.addHours(3);
    public static final String DEFAULT_COMPONENTS = '*';
    public static final Integer RENAME_LOCK_TIMEOUT_HOURS = 4;

    public Boolean isScanDeactivationPending {get; set;}
    public Boolean isButrDeactivationPending {get; set;}
    public Boolean isInstanceRenamePending {get; set;}
    public Boolean isInstanceRenameLocked {get; set;}
    public String id {get; set;}
    public String name {get; set;}
    public String customDomain {get; set;}
    public String instanceType {get; set;}
    public List<String> instanceTypes {get; set;}
    public List<ALMApplicationResultModel> scanResults {get; set;}
    public List<ALMApplicationResultModel> butrResults {get; set;}
    public ScanResult lastScanResult {get; set;}

    public ALM_Job__c scanJob {get; set;}
    public ALM_Job__c butrJob {get; set;}

    public Instances__c record {get; set;}

    public Long scanStartTime {
        get {
            return ALMJobServices.getJobTime(scanJob, ALM_Job__c.Scheduled_Start_Time__c);
        }
        set {
            setJobTime(scanJob, ALM_Job__c.Scheduled_Start_Time__c, value);
        }

    }

    public Long scanEndTime {
        get {
            return ALMJobServices.getJobTime(scanJob, ALM_Job__c.Scheduled_End_Time__c);
        }
        set {
            setJobTime(scanJob, ALM_Job__c.Scheduled_End_Time__c, value);
        }
    }

    public Long butrStartTime {
        get {
            return ALMJobServices.getJobTime(butrJob, ALM_Job__c.Scheduled_Start_Time__c);
        }
        set {
            setJobTime(butrJob, ALM_Job__c.Scheduled_Start_Time__c, value);
        }
    }
    public Long butrEndTime {
        get {
            return ALMJobServices.getJobTime(butrJob, ALM_Job__c.Scheduled_End_Time__c);
        }
        set {
            setJobTime(butrJob, ALM_Job__c.Scheduled_End_Time__c, value);
        }
    }

    // Set epoch-formatted time.
    private void setJobTime(ALM_Job__c job, Schema.SObjectField timeField, Long timeValue) {
        if (job != null && timeField != null && timeValue != null) {
            job.put(timeField, DateTime.newInstance(timeValue));
        }
    }

    public Boolean hasActiveScanJob {
        get {
            return scanJob != null && scanJob.Id != null;
        }

        private set;
    }

    public Boolean hasActiveButrJob {
        get {
            return butrJob != null && butrJob.Id != null;
        }

        private set;
    }

    public Boolean instanceCreated {
        get {
            return record != null && record.Id != null;
        }
    }

    public InstanceModel(Instances__c instance) {
        this.record = instance;
        this.id = instance.Id;
        this.name = instance.Name;
        this.customDomain = instance.Custom_Domain__c;
        this.instanceType = instance.Type__c;
        this.instanceTypes = InstanceServices.getInstanceTypes();
        this.scanResults = new List<ALMApplicationResultModel>();
        this.butrResults = new List<ALMApplicationResultModel>();
        this.isScanDeactivationPending = false;
        this.isButrDeactivationPending = false;
        this.isInstanceRenamePending = false;
        this.isInstanceRenameLocked = false;
    }

    public InstanceModel(Instances__c instance, ALM_Job__c scanJob) {
        this(instance);
        this.scanJob = scanJob;
    }

    public void initNewScanJob() {
        scanJob = initNewJob();
        scanJob.Tool__c = ALMJobServices.getToolName(ALMJobServices.ToolType.SCAN);
        scanJob.Components__c = DEFAULT_COMPONENTS;
        setScanJobTargetInstance();
        scanJob.Interval__c = DEFAULT_SCAN_INTERVAL;
        scanJob.Scheduled_Start_Time__c = DEFAULT_SCAN_START_TIME;
        scanJob.Scheduled_End_Time__c = DEFAULT_SCAN_END_TIME;
        this.isScanDeactivationPending = false;
    }

    public void initNewButrJob() {
        butrJob = initNewJob();
        butrJob.Tool__c = ALMJobServices.getToolName(ALMJobServices.ToolType.AUTOMATED_TESTING);
        butrJob.Interval__c = DEFAULT_BUTR_INTERVAL;
        butrJob.Scheduled_Start_Time__c = DEFAULT_BUTR_START_TIME;
        butrJob.Scheduled_End_Time__c = DEFAULT_BUTR_END_TIME;
        this.isButrDeactivationPending = false;
    }

    private ALM_Job__c initNewJob() {
        ALM_Job__c job = new ALM_Job__c();

        job.Source_Instance__c = id;
        job.Status__c = SCANServices.TOOL_STATUS_SCHEDULED;
        job.Scheduled_On_Monday__c = true;
        job.Scheduled_On_Tuesday__c = true;
        job.Scheduled_On_Wednesday__c = true;
        job.Scheduled_On_Thursday__c = true;
        job.Scheduled_On_Friday__c = true;

        return job;
    }

    public void setScanJobTargetInstance() {
        if (scanJob == null) {
            return;
        }
        Instances__c target = InstanceServices.almInstance;
        scanJob.Target_Instance__c = (target == null) ? null : target.Id;
    }

    public Integer compareTo(Object otherObject) {
        return this.name.compareTo(((InstanceModel)otherObject).name);
    }

    public Boolean checkIsRenameLocked() {
        Instances__c instance = InstanceServices.getInstance(this.id);

        if (instance == null || instance.Rename_Lock_Expiration_Time__c == null) {
            return false;
        }

        // The rename lock should expire after a specified timeout period to prevent a record from being perpetually locked in the event that a task fails to unlock it properly.
        Integer lockTimeElapsedMilliseconds = (Integer)(DateTime.now().getTime() - instance.Rename_Lock_Expiration_Time__c);
        this.isInstanceRenameLocked = lockTimeElapsedMilliseconds < 0;
        
        return this.isInstanceRenameLocked;
    }

    /**
    * @throws DMLException, QueryException
    */
    public void setRenameLock() {
        mutateRenameLock(true);
    }

    /**
    * @throws DMLException, QueryException
    */
    public void clearRenameLock() {
        mutateRenameLock(false);
    }

    /**
    * @throws DMLException, QueryException
    * @param locked - The new state of the rename lock.
    */
    private void mutateRenameLock(Boolean locked) {
        List<Instances__c> instances;
        instances = [SELECT Rename_Lock_Expiration_Time__c FROM Instances__c WHERE Id = :this.id FOR UPDATE];
        if (instances.isEmpty()) {
            return;
        }
        Instances__c instance = instances[0];

        instance.Rename_Lock_Expiration_Time__c = locked ? DateTime.now().addHours(RENAME_LOCK_TIMEOUT_HOURS).getTime() : null;
        update instance;

        this.isInstanceRenameLocked = locked;
    }

    /**
    * Represents a SCAN tool result.
    */
    public class ScanResult {
        public String instanceId {get; set;}
        public String lastRunTime {get; set;}
        public String result {get; set;}
        public ALM_Application_Result__c record {get; set;}
        public Boolean hasScanRan {get; set;}
        public Boolean isSuccess {get; set;}
        public Boolean isWarnings {get; set;}
        public Boolean isFailure {get; set;}

        public ScanResult(ALM_Application_Result__c applicationResult) {
            this.instanceId = applicationResult.Instance__c;
            this.lastRunTime = (applicationResult.Run_Time__c == null) ? '' : applicationResult.Run_Time__c.format();
            this.result = applicationResult.Result__c;
            this.record = applicationResult;
            this.hasScanRan = true;
            this.isSuccess = ScanServices.SUCCESS_STATUS.equalsIgnoreCase(this.result) ? true : false;
            this.isWarnings = ScanServices.SUCCESS_WITH_WARNINGS_STATUS.equalsIgnoreCase(this.result) ? true : false;
            this.isFailure = ScanServices.FAILURE_STATUS.equalsIgnoreCase(this.result) ? true : false;

        }

        public ScanResult(String instanceId) {
            this.instanceId = instanceId;
            this.lastRunTime = 'N/A';
            this.result = '-';
            this.hasScanRan = false;
            this.isSuccess = false;
            this.isWarnings = false;
            this.isFailure = false;
        }
    }
}