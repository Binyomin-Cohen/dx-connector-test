public with sharing class VCRepository {
    @AuraEnabled
    public Id id {get; set;}
    @AuraEnabled
    public String metadataPath {get; set;}
    @AuraEnabled
    public String name {get; set;}
    @AuraEnabled
    public String repositoryUrl {get; set;}
    @AuraEnabled
    public String host {get; set;}
    @AuraEnabled
    public Boolean enableExternalCommitLink {get; set;}
    @AuraEnabled
    public String orgName {get; set;}
    @AuraEnabled
    public Validation validation {get; set;}
    @AuraEnabled
    public AuraALMJob job {get; set;}
    @AuraEnabled
    public Date syncDate {get; set;}
    @AuraEnabled
    public String sourceFormat{get; set;}

    private static String METADATA_API = 'Metadata API';

    public VCRepository(VC_Repository__c repoRecord) {
        this.id = repoRecord.Id;
        this.name = repoRecord.Name;
        this.metadataPath = repoRecord.SFDC_Metadata_Path__c;
        this.repositoryUrl = repoRecord.Repository_URL__c;
        this.host = repoRecord.Host__c;
        this.enableExternalCommitLink = repoRecord.Enable_External_Commit_Link__c;
        this.orgName = repoRecord.Organization_Name__c;
        this.syncDate = repoRecord.Sync_Revisions_From__c == null ? null : repoRecord.Sync_Revisions_From__c.Date();
        this.sourceFormat = repoRecord.Source_Format__c == null ? null : repoRecord.Source_Format__c;
    }

    public VCRepository(VC_Repository__c repoRecord, List<VC_Repository_Validation__c> validations) {
        this(repoRecord);
        if (!validations.isEmpty()) {
            this.validation = new Validation(validations[0]);
        }
    }
    public VCRepository(VC_Repository__c repoRecord, ALM_Job__c almJob) {
        this(repoRecord);
        if (almJob != null) {
            this.job = new AuraALMJob(almJob);
        }
    }
    public VC_Repository__c getRepo() {
        VC_Repository__c repoToReturn = new VC_Repository__c();
        repoToReturn.Id = id;
        repoToReturn.Name = name;
        repoToReturn.SFDC_Metadata_Path__c = metadataPath;
        repoToReturn.Repository_URL__c = repositoryUrl;
        repoToReturn.Enable_External_Commit_Link__c = enableExternalCommitLink;
        repoToReturn.Host__c = host;
        repoToReturn.Organization_Name__c = orgName;
        repoToReturn.Sync_Revisions_From__c = syncDate == null ? null : DateTime.newInstance(syncDate.year(), syncDate.month(), syncDate.day());
        repoToReturn.Source_Format__c = sourceFormat == null ? METADATA_API : sourceFormat;
        return repoToReturn;
    }
    public class Validation {
        @AuraEnabled
        public Id id {get; set;}
        @AuraEnabled
        public Boolean isSuccessful {get; set;}
        @AuraEnabled
        public DateTime validationDate {get; set;}
        @AuraEnabled
        public String error {get; set;}
        @AuraEnabled
        public String externalId {get; set;}

        public Validation(VC_Repository_Validation__c validation) {
            this.id = validation.Id;
            this.isSuccessful = validation.SuccessfulValidation__c;
            this.validationDate = validation.ValidationDate__c;
            this.error = validation.ValidationError__c;
            this.externalId = validation.ExternalID__c;
        }
    }

    public with sharing class AuraALMJob {
        @AuraEnabled
        public Id id {get; set;}
        @AuraEnabled
        public String tool {get; set;}
        @AuraEnabled
        public String status {get; set;}
        @AuraEnabled
        public String mailTo {get; set;}
        @AuraEnabled
        public Long scheduledStartTime {get; set;}
        @AuraEnabled
        public Long scheduledEndTime {get; set;}
        @AuraEnabled
        public DateTime lastQueueTime {get; set;}
        @AuraEnabled
        public Decimal interval {get; set;}
        @AuraEnabled
        public Boolean scheduledOnMonday {get; set;}
        @AuraEnabled
        public Boolean scheduledOnTuesday {get; set;}
        @AuraEnabled
        public Boolean scheduledOnWednesday {get; set;}
        @AuraEnabled
        public Boolean scheduledOnThursday {get; set;}
        @AuraEnabled
        public Boolean scheduledOnFriday {get; set;}
        @AuraEnabled
        public Boolean scheduledOnSaturday {get; set;}
        @AuraEnabled
        public Boolean scheduledOnSunday {get; set;}
        @AuraEnabled
        public List<ALMApplicationResultModel> applicationResults {get; set;}
        

        public AuraALMJob(ALM_Job__c job) {
            this.id = job.Id;
            this.tool = job.Tool__c;
            this.status = job.Status__c;
            this.mailTo = job.Mail_To__c;
            this.scheduledStartTime = ALMJobServices.getJobTime(job, ALM_Job__c.Scheduled_Start_Time__c);
            this.scheduledEndTime = ALMJobServices.getJobTime(job, ALM_Job__c.Scheduled_End_Time__c);
            this.lastQueueTime = job.Last_Queue_Time__c;
            this.interval = job.Interval__c;
            this.scheduledOnMonday = job.Scheduled_On_Monday__c;
            this.scheduledOnTuesday = job.Scheduled_On_Tuesday__c;
            this.scheduledOnWednesday = job.Scheduled_On_Wednesday__c;
            this.scheduledOnThursday = job.Scheduled_On_Thursday__c;
            this.scheduledOnFriday = job.Scheduled_On_Friday__c;
            this.scheduledOnSaturday = job.Scheduled_On_Saturday__c;
            this.scheduledOnSunday = job.Scheduled_On_Sunday__c;
            this.applicationResults = convertALMApplicationResultsToModels(job.ALM_Application_Results__r);
        }
        public ALM_Job__c getJob() {
            ALM_Job__c jobToReturn = new ALM_Job__c();
            jobToReturn.Id = id;
            jobToReturn.Tool__c = ALMJobServices.getToolName(ALMJobServices.ToolType.VC_REPO_SYNC);
            jobToReturn.Status__c = status;
            jobToReturn.Mail_To__c = mailTo;
            jobToReturn.Scheduled_Start_Time__c = DateTime.newInstance(scheduledStartTime);
            jobToReturn.Scheduled_End_Time__c = DateTime.newInstance(scheduledEndTime);
            jobToReturn.Last_Queue_Time__c = lastQueueTime;
            jobToReturn.Interval__c = interval;
            jobToReturn.Scheduled_On_Monday__c = scheduledOnMonday;
            jobToReturn.Scheduled_On_Tuesday__c = scheduledOnTuesday;
            jobToReturn.Scheduled_On_Wednesday__c = scheduledOnWednesday;
            jobToReturn.Scheduled_On_Thursday__c = scheduledOnThursday;
            jobToReturn.Scheduled_On_Friday__c = scheduledOnFriday;
            jobToReturn.Scheduled_On_Saturday__c = scheduledOnSaturday;
            jobToReturn.Scheduled_On_Sunday__c = scheduledOnSunday;
            return jobToReturn;
        }
        
        public List<ALMApplicationResultModel> convertALMApplicationResultsToModels (List<ALM_Application_Result__c> results) {
            List<ALMApplicationResultModel> modelsToReturn = new List<ALMApplicationResultModel>();
            for (ALM_Application_Result__c result : results) {
                modelsToReturn.add( new ALMApplicationResultModel(result) );
            }
            return modelsToReturn;
        }
    }

}