public with sharing class AdminInstanceManagementController extends OAuthController {
    @TestVisible
    private static final String PAGE_STATE_TOKEN = 'PageState AdminInstanceManagement';
    public static final String UNAUTHORIZED_ENDPOINT_IDENTIFIER = 'Unauthorized endpoint';
    @TestVisible
    private static final String NO_AUTH_USER_URL_ERROR = 'Not Authorized';

    public InstanceModel currentInstance {get; set;}
    public InstanceModel newInstance {get; set;}
    public Boolean isInstanceDeleted {get; set;}

    public Boolean hasPermissions {get; set;}

    public String currentInstanceJSON {
        get {
            if(currentInstance == null) {
                return '{}';
            }
            return JSON.serialize(currentInstance);
        }
    }

    public List<InstanceModel> allInstances {get; set;}

    public Boolean hasSaveErrors {get; set;}
    public Boolean wasSaveTriggered {get; set;}
    public Boolean isScanActivated {get; set;}
    public Boolean isButrActivated {get; set;}

    public Boolean isPageRestored {get; set;}
    public Boolean isScanRestored {get; set;}
    public Boolean isButrRestored {get; set;}
    public String namespace {get; set;}

    public List<PageMessage> pageMessages {get; set;}

    public String userTimeZone {
        get {
            return UserInfo.getTimeZone().getId();
        }
    }

    public static final String NO_SCAN_JOB_FOUND_MSG = ': No SCAN job found for this source instance ID.';

    public AdminInstanceManagementController() {
        namespace = SObjectServices.getNameSpace();
        pageMessages = validateAuth();
        verifyPagePermissions();

        allInstances = getAllInstances();

        initNewInstanceModel();

        hasSaveErrors = false;

        selectedInstanceId = ApexPages.currentPage().getParameters().get('id');

        if (String.isNotEmpty(selectedInstanceId)) {
            loadInstance();
        }
    }

    private void initNewInstanceModel() {
        newInstance = new InstanceModel(new Instances__c());
        newInstance.record.Type__c = '';
    }

    public void loadInstance() {
        currentInstance = InstanceServices.getInstanceModel(selectedInstanceId);
        if (currentInstance == null) {
            addGenericPageError('Instance not found.');
            return;
        }

        currentInstance.checkIsRenameLocked();

        getScanResults();
        getButrResults();

        // Check for an existing SCAN job, or initialize a new one.
        ALM_Job__c scanJob;
        try {
            scanJob = SCANServices.getScanJobForInstance(selectedInstanceId);
        } catch(ALMException e) {
            addGenericPageError(e.getMessage());
            return;
        }

        if (scanJob == null) {
            currentInstance.initNewScanJob();
            isScanActivated = false;
        } else {
            currentInstance.scanJob = scanJob;
            if (scanJob.Target_Instance__c == null) {
                currentInstance.setScanJobTargetInstance();
            }
            isScanActivated = true;
        }

        // Check for an existing BUTR job, or initialize a new one.
        ALM_Job__c butrJob;
        try {
            butrJob = ALMJobServices.getButrJobForInstance(selectedInstanceId);
        } catch(ALMException e) {
            addGenericPageError(e.getMessage());
            return;
        }

        if (butrJob == null) {
            currentInstance.initNewButrJob();
            isButrActivated = false;
        } else {
            currentInstance.butrJob = butrJob;
            isButrActivated = true;
        }

        initialPageStateMap = getCurrentPageStateMap();
        restorePageState();

        pageMessages = validateAuth();
    }

    public void getScanResults() {
        List<ALMApplicationResultModel> scanResults = ALMApplicationResultServices.getAlmApplicationResults(selectedInstanceId, ALMJobServices.ToolType.SCAN);

        if (scanResults.size() > 0) {
            currentInstance.scanResults = scanResults;
        }
    }

    public void getButrResults() {
        List<ALMApplicationResultModel> butrResults = ALMApplicationResultServices.getAlmApplicationResults(selectedInstanceId, ALMJobServices.ToolType.AUTOMATED_TESTING);

        if (butrResults.size() > 0) {
            currentInstance.butrResults = butrResults;
        }
    }

    public void pollScanJob() {
        try {
            currentInstance.scanJob.Status__c = getJobStatus(currentInstance.id, ALMJobServices.getToolName(ALMJobServices.ToolType.SCAN).toLowerCase());
        } catch (ALMException e) {
            addGenericPageError(e.getMessage());
        }

        getScanResults();
    }

    @RemoteAction
    public static String calloutTest(Id instanceId) {
         String errorMessage;
         Auth_User__c auth = OAuthServices.getAuthUserForTools(instanceId);
         if (auth == null || String.isBlank(auth.Instance_Url__c)) {
             return NO_AUTH_USER_URL_ERROR;
         }
         String endpoint = auth.Instance_Url__c;
         try {
             ALMRestServices.makeGetRequest(endpoint);
         } catch (ALMException almEx ){
             if(almEx.getMessage().contains(UNAUTHORIZED_ENDPOINT_IDENTIFIER)) {
                 return auth.Instance_Url__c;
             }
         }
       return errorMessage;

    }
    public void createOnDemandButrRequest() {
        if(String.isBlank(selectedInstanceId)) {
            addGenericPageError('You must select an instance before sending an Automated Testing request.');
            return;
        }

        try {
            currentInstance.butrJob = ALMJobServices.getButrJobForInstance(selectedInstanceId);
        } catch(ALMException e) {
            addGenericPageError(e.getMessage());
            return;
        }

        if (currentInstance.butrJob.Status__c != SCANServices.TOOL_STATUS_SCHEDULED) {
            addGenericPageError('Automated Testing is already running.');
            return;
        }

        pageMessages = validateAuth(false);

        if (pageMessages.isEmpty()) {
            try {
                currentInstance.butrJob.Status__c = SCANServices.TOOL_STATUS_QUEUED;
                update currentInstance.butrJob;
            } catch(DMLException de) {
                addGenericPageError(de.getMessage());
                return;
            }

            ALMJobServices.startBUTRJobs(new Set<Id> { currentInstance.butrJob.Id });
        }
    }

    public void createOnDemandScanRequest() {
        if (currentInstance.checkIsRenameLocked()) {
            return;
        }

        if(String.isBlank(selectedInstanceId)) {
            addGenericPageError('You must select an instance before sending a SCAN request.');
            return;
        }

        ALM_Job__c job;
        try {
            job = SCANServices.getScanJobForInstance(selectedInstanceId);
        } catch(ALMException e) {
            addGenericPageError(e.getMessage());
            return;
        }

        if (job == null) {
            addGenericPageError(NO_SCAN_JOB_FOUND_MSG);
            return;
        }

        pageMessages = validateAuth();

        if (pageMessages.isEmpty()) {
            if (job.Target_Instance__c == null) {
                job.Target_Instance__c = InstanceServices.almInstance.Id;
            }

            try {
                job.Status__c = SCANServices.TOOL_STATUS_QUEUED;
                update job;
            } catch(DMLException de) {
                addGenericPageError(de.getMessage());
                return;
            }

            try {
                ALMApplicationResultServices.createApplicationResult(
                    job,
                    ALMJobServices.ToolType.SCAN,
                    SCANServices.TOOL_STATUS_QUEUED
                );
            } catch (ALMException e) {
                addGenericPageError(e.getMessage());
                return;
            }

            SCANServices.sendScanJobRequest(new Set<Id> { job.Id });
        }
    }

    public void save() {
        wasSaveTriggered = true;

        if (currentInstance.isScanDeactivationPending) {
            deleteScanJob();
            currentInstance.isScanDeactivationPending = false;
        }

        if (currentInstance.isButrDeactivationPending) {
            deleteButrJob();
            currentInstance.isButrDeactivationPending = false;
        }

        SCANServices.ensureScanJobSchedulesExist();

        System.Savepoint sp = Database.setSavePoint();

        Boolean scanJobExists = currentInstance.hasActiveScanJob;

        Boolean willExecuteRename = false;
        String oldInstanceName = currentInstance.record.Name;
        if (currentInstance.isInstanceRenamePending) {
            try {
                if (!currentInstance.checkIsRenameLocked() &&
                    currentInstance.scanJob.Status__c != SCANServices.TOOL_STATUS_QUEUED &&
                    currentInstance.scanJob.Status__c != SCANServices.TOOL_STATUS_RUNNING
                ) {
                    currentInstance.setRenameLock();
                    currentInstance.record.Name = currentInstance.name;
                    willExecuteRename = true;
                } else {
                    currentInstance.name = oldInstanceName;
                    addGenericPageError('Could not rename instance.');
                }
                currentInstance.isInstanceRenamePending = false;
            } catch (Exception e) {
                ALMLogServices.error(e, ALMLogServices.Application.ADMIN_CONSOLE);
                return;
            }
        }

        try {
            update currentInstance.record;

            expirePageState();
            initialPageStateMap = getCurrentPageStateMap();

            allInstances = getAllInstances();

            if (isScanActivated || isButrActivated) {
                if (isScanActivated) {
                    upsert currentInstance.scanJob;
                }
                if (isButrActivated) {
                    upsert currentInstance.butrJob;
                }
                pageMessages = validateAuth();
            }

            if (willExecuteRename) {
                Database.executeBatch(new InstanceRenameComponentsBatch(currentInstance.id, oldInstanceName, currentInstance.record.Name));
            }
        } catch (DMLException de) {
            ApexPages.addMessages(de);
            hasSaveErrors = true;
            Database.rollback(sp);
            if (!scanJobExists && isScanActivated) {
                //rollback will not reset the id, so we need to set it manually
                currentInstance.scanJob = currentInstance.scanJob.clone(false);
            }
            return;
        }

        hasSaveErrors = false;
    }

    public void deleteScanJob() {
        if (currentInstance == null) {
            return;
        }

        try {
            if (currentInstance.hasActiveScanJob) {
                pageMessages.clear();
                delete new ALM_Job__c(Id=currentInstance.scanJob.Id);
            }
        } catch (DMLException de) {
            ApexPages.addMessages(de);
            return;
        }

        currentInstance.initNewScanJob();
        isScanActivated = false;
    }

    public void deleteButrJob() {
        if (currentInstance == null) {
            return;
        }

        try {
            if (currentInstance.hasActiveButrJob) {
                pageMessages.clear();
                delete new ALM_Job__c(Id=currentInstance.butrJob.Id);
            }
        } catch (DMLException de) {
            ApexPages.addMessages(de);
            return;
        }

        currentInstance.initNewButrJob();
        isButrActivated = false;
    }

    public void getAllScanResults() {
        List<String> instanceIds = new List<String>();
        for (InstanceModel model : allInstances) {
            instanceIds.add(model.id);
        }

        Map<String, InstanceModel.ScanResult> instanceIdToScanResult = InstanceServices.fetchScanResult(instanceIds);
        for (InstanceModel model : allInstances) {
            InstanceModel.ScanResult scanResult = instanceIdToScanResult.get(model.id);
            if (scanResult != null) {
                model.lastScanResult = scanResult;
            }
        }
    }

    public static List<InstanceModel> getAllInstances() {
        List<InstanceModel> models = new List<InstanceModel>();

        for (Instances__c instance : InstanceServices.getAllInstances()) {
            models.add(new InstanceModel(instance));
        }

        return models;
    }

    /**
    * @throws ALMException
    */
    public void addNewInstance() {
        if (newInstance != null) {
            Instances__c existingInstance = InstanceServices.checkInstanceNameUniqueness(newInstance.record.Name);
            if(existingInstance != null && existingInstance.Is_Deleted__c == true ){
                isInstanceDeleted = true;
                return;
            } else {
                isInstanceDeleted = false;
            }
            try {
                InstanceServices.addNewInstance(newInstance);
                currentInstance = null;
            } catch (ALMException e) {
                addGenericPageError(e.getMessage());
            }

            newInstance.id = newInstance.record.Id;
            newInstance.name = newInstance.record.Name;
            newInstance.lastScanResult = new InstanceModel.ScanResult(newInstance.record.Id);

            allInstances.add(newInstance);
            allInstances.sort();

            initNewInstanceModel();
        }
    }

    /**
    * @throws ALMException
    */
    public void undeleteInstance() {
        if (newInstance != null) {
            try{
                InstanceServices.undeleteInstance(InstanceServices.checkInstanceNameUniqueness(newInstance.record.Name));
                isInstanceDeleted = false;
                allInstances = getAllInstances();
            } catch (Exception ex) {
                addGenericPageError(ex.getMessage());
            }
        }
    }

    public void deleteInstance() {
        deleteScanJob();
        deleteButrJob();

        try {
            if (!InstanceServices.softDeleteInstance(currentInstance.id)) {
                pageMessages.add(new PageMessage(
                    ApexPages.Severity.ERROR,
                    System.Label.Generic_Error + ': Cannot delete instance with ID ' + currentInstance.id + '.'
                ));
            }
        } catch (DMLException e) {
            pageMessages.add(new PageMessage(
                ApexPages.Severity.ERROR,
                System.Label.Generic_Error + ': ' + e.getMessage()
            ));
        }
    }

    public void updateAuthMessages() {
        pageMessages = validateAuth();
    }

    /**
    * Returns the status for the job based on jobType
    * @param Id sourceInstanceId, String jobType
    * @return String status
    * @throws ALMException
    */
    @RemoteAction
    public static String getJobStatus(Id sourceInstanceId, String jobType) {

        ALM_Job__c job;
        if (jobType.equals('scan')) {
            job = SCANServices.getScanJobForInstance(sourceInstanceId);
        } else {
            job = ALMJobServices.getButrJobForInstance(sourceInstanceId);
        }

        if (job == null) {
            throw new ALMException(NO_SCAN_JOB_FOUND_MSG);
        }

        return job.Status__c;
    }

    @TestVisible
    protected override Map<String, Object> getCurrentPageStateMap() {
        Map<String, Object> currentPageStateMap = new Map<String, Object>{
            'name' => (!String.isBlank(currentInstance.Name) ? currentInstance.Name : null),
            'type' => (!String.isBlank(currentInstance.record.Type__c) ? currentInstance.record.Type__c : null),
            'domain' => (!String.isBlank(currentInstance.record.Custom_Domain__c) ? currentInstance.record.Custom_Domain__c : null),
            'isScanActivated' => isScanActivated,
            'isButrActivated' => isButrActivated
        };

        if (isScanActivated) {
            currentPageStateMap.put('scanEmail', currentInstance.scanJob.Mail_To__c);
            currentPageStateMap.put('scanStatus', currentInstance.scanJob.Status__c);
            currentPageStateMap.put('scanScheduledMonday', currentInstance.scanJob.Scheduled_On_Monday__c);
            currentPageStateMap.put('scanScheduledTuesday', currentInstance.scanJob.Scheduled_On_Tuesday__c);
            currentPageStateMap.put('scanScheduledWednesday', currentInstance.scanJob.Scheduled_On_Wednesday__c);
            currentPageStateMap.put('scanScheduledThursday', currentInstance.scanJob.Scheduled_On_Thursday__c);
            currentPageStateMap.put('scanScheduledFriday', currentInstance.scanJob.Scheduled_On_Friday__c);
            currentPageStateMap.put('scanScheduledSaturday', currentInstance.scanJob.Scheduled_On_Saturday__c);
            currentPageStateMap.put('scanScheduledSunday', currentInstance.scanJob.Scheduled_On_Sunday__c);
            currentPageStateMap.put('scanFrequency', currentInstance.scanJob.Interval__c);
            currentPageStateMap.put('scanStartTime', currentInstance.scanStartTime);
            currentPageStateMap.put('scanEndTime', currentInstance.scanEndTime);
        }

        if (isButrActivated) {
            currentPageStateMap.put('butrEmail', currentInstance.butrJob.Mail_To__c);
            currentPageStateMap.put('butrStatus', currentInstance.butrJob.Status__c);
            currentPageStateMap.put('butrScheduledMonday', currentInstance.butrJob.Scheduled_On_Monday__c);
            currentPageStateMap.put('butrScheduledTuesday', currentInstance.butrJob.Scheduled_On_Tuesday__c);
            currentPageStateMap.put('butrScheduledWednesday', currentInstance.butrJob.Scheduled_On_Wednesday__c);
            currentPageStateMap.put('butrScheduledThursday', currentInstance.butrJob.Scheduled_On_Thursday__c);
            currentPageStateMap.put('butrScheduledFriday', currentInstance.butrJob.Scheduled_On_Friday__c);
            currentPageStateMap.put('butrScheduledSaturday', currentInstance.butrJob.Scheduled_On_Saturday__c);
            currentPageStateMap.put('butrScheduledSunday', currentInstance.butrJob.Scheduled_On_Sunday__c);
            currentPageStateMap.put('butrFrequency', currentInstance.butrJob.Interval__c);
            currentPageStateMap.put('butrStartTime', currentInstance.butrStartTime);
            currentPageStateMap.put('butrEndTime', currentInstance.butrEndTime);
        }

        return currentPageStateMap;
    }

    protected override String getPageStateToken() {
        return PAGE_STATE_TOKEN;
    }

    @TestVisible
    private void restorePageState() {
        Map<String, Object> pageStateMap = loadPageState();
        if (pageStateMap != null && !pageStateMap.isEmpty()) {
            isPageRestored = true;

            if (pageStateMap.containsKey('name')) {
                currentInstance.Name = String.valueOf(pageStateMap.get('name'));
            }
            if (pageStateMap.containsKey('type')) {
                currentInstance.record.Type__c = String.valueOf(pageStateMap.get('type'));
            }
            if (pageStateMap.containsKey('domain')) {
                currentInstance.record.Custom_Domain__c = String.valueOf(pageStateMap.get('domain'));
            }

            if (pageStateMap.containsKey('isScanActivated')) {
                isScanActivated = Boolean.valueOf(pageStateMap.get('isScanActivated'));
            }

            if (isScanActivated) {
                for (String key : pageStateMap.keySet()) {
                    if (key.startsWith('scan')) {
                        isScanRestored = true;
                        break;
                    }
                }

                if (pageStateMap.containsKey('scanEmail')) {
                    currentInstance.scanJob.Mail_To__c = String.valueOf(pageStateMap.get('scanEmail'));
                }
                if (pageStateMap.containsKey('scanStatus')) {
                    currentInstance.scanJob.Status__c = String.valueOf(pageStateMap.get('scanStatus'));
                }
                if (pageStateMap.containsKey('scanScheduledMonday')) {
                    currentInstance.scanJob.Scheduled_On_Monday__c = Boolean.valueOf(pageStateMap.get('scanScheduledMonday'));
                }
                if (pageStateMap.containsKey('scanScheduledTuesday')) {
                    currentInstance.scanJob.Scheduled_On_Tuesday__c = Boolean.valueOf(pageStateMap.get('scanScheduledTuesday'));
                }
                if (pageStateMap.containsKey('scanScheduledWednesday')) {
                    currentInstance.scanJob.Scheduled_On_Wednesday__c = Boolean.valueOf(pageStateMap.get('scanScheduledWednesday'));
                }
                if (pageStateMap.containsKey('scanScheduledThursday')) {
                    currentInstance.scanJob.Scheduled_On_Thursday__c = Boolean.valueOf(pageStateMap.get('scanScheduledThursday'));
                }
                if (pageStateMap.containsKey('scanScheduledFriday')) {
                    currentInstance.scanJob.Scheduled_On_Friday__c = Boolean.valueOf(pageStateMap.get('scanScheduledFriday'));
                }
                if (pageStateMap.containsKey('scanScheduledSaturday')) {
                    currentInstance.scanJob.Scheduled_On_Saturday__c = Boolean.valueOf(pageStateMap.get('scanScheduledSaturday'));
                }
                if (pageStateMap.containsKey('scanScheduledSunday')) {
                    currentInstance.scanJob.Scheduled_On_Sunday__c = Boolean.valueOf(pageStateMap.get('scanScheduledSunday'));
                }
                if (pageStateMap.containsKey('scanFrequency')) {
                    currentInstance.scanJob.Interval__c = Integer.valueOf(pageStateMap.get('scanFrequency'));
                }
                if (pageStateMap.containsKey('scanStartTime')) {
                    currentInstance.scanStartTime = (Long)pageStateMap.get('scanStartTime');
                }
                if (pageStateMap.containsKey('scanEndTime')) {
                    currentInstance.scanEndTime = (Long)pageStateMap.get('scanEndTime');
                }
            }

            if (pageStateMap.containsKey('isButrActivated')) {
                isButrActivated = Boolean.valueOf(pageStateMap.get('isButrActivated'));
            }

            if (isButrActivated) {
                for (String key : pageStateMap.keySet()) {
                    if (key.startsWith('butr')) {
                        isButrRestored = true;
                        break;
                    }
                }

                if (pageStateMap.containsKey('butrEmail')) {
                    currentInstance.butrJob.Mail_To__c = String.valueOf(pageStateMap.get('butrEmail'));
                }
                if (pageStateMap.containsKey('butrStatus')) {
                    currentInstance.butrJob.Status__c = String.valueOf(pageStateMap.get('butrStatus'));
                }
                if (pageStateMap.containsKey('butrScheduledMonday')) {
                    currentInstance.butrJob.Scheduled_On_Monday__c = Boolean.valueOf(pageStateMap.get('butrScheduledMonday'));
                }
                if (pageStateMap.containsKey('butrScheduledTuesday')) {
                    currentInstance.butrJob.Scheduled_On_Tuesday__c = Boolean.valueOf(pageStateMap.get('butrScheduledTuesday'));
                }
                if (pageStateMap.containsKey('butrScheduledWednesday')) {
                    currentInstance.butrJob.Scheduled_On_Wednesday__c = Boolean.valueOf(pageStateMap.get('butrScheduledWednesday'));
                }
                if (pageStateMap.containsKey('butrScheduledThursday')) {
                    currentInstance.butrJob.Scheduled_On_Thursday__c = Boolean.valueOf(pageStateMap.get('butrScheduledThursday'));
                }
                if (pageStateMap.containsKey('butrScheduledFriday')) {
                    currentInstance.butrJob.Scheduled_On_Friday__c = Boolean.valueOf(pageStateMap.get('butrScheduledFriday'));
                }
                if (pageStateMap.containsKey('butrScheduledSaturday')) {
                    currentInstance.butrJob.Scheduled_On_Saturday__c = Boolean.valueOf(pageStateMap.get('butrScheduledSaturday'));
                }
                if (pageStateMap.containsKey('butrScheduledSunday')) {
                    currentInstance.butrJob.Scheduled_On_Sunday__c = Boolean.valueOf(pageStateMap.get('butrScheduledSunday'));
                }
                if (pageStateMap.containsKey('butrFrequency')) {
                    currentInstance.butrJob.Interval__c = Integer.valueOf(pageStateMap.get('butrFrequency'));
                }
                if (pageStateMap.containsKey('butrStartTime')) {
                    currentInstance.butrStartTime = (Long)pageStateMap.get('butrStartTime');
                }
                if (pageStateMap.containsKey('butrEndTime')) {
                    currentInstance.butrEndTime = (Long)pageStateMap.get('butrEndTime');
                }
            }
        }
    }

    private void addGenericPageError(String msg) {
        ApexPages.addMessage(new ApexPages.Message(
            ApexPages.Severity.ERROR,
            System.Label.Generic_Error + ': ' + msg
        ));
    }

    private void verifyPagePermissions() {
        AdminSettingsPermissions appPermissions = new AdminSettingsPermissions();
        hasPermissions = appPermissions.hasPermission() == PermissionServices.PermissionLevel.FULL;
        if (!hasPermissions) {
            pageMessages.add( new PageMessage(
                ApexPages.Severity.ERROR,
                System.Label.Permissions_Error
            ));
        }
    }

    private List<PageMessage> validateAuth() {
        return validateAuth(true);
    }

    @TestVisible
    private List<PageMessage> validateAuth(Boolean checkSightlineAuth) {
        List<PageMessage> messages = new List<PageMessage>();
        String settingsLinkHTML = '<a href=\'/apex/' + SObjectServices.getFullyQualifiedName('AdminAlmSettings') + '\'>Sightline Settings &gt;</a>';

        if (currentInstance != null && (isScanActivated || isButrActivated)) {
            Auth_User__c auth = OAuthServices.getAuthUserForTools(currentInstance.Id);
            if (auth == null || !auth.Is_Refresh_Token_Valid__c) {
                if (isScanActivated) {
                    messages.add( new PageMessage(
                        ApexPages.Severity.ERROR,
                        String.format(System.Label.Tool_Connection_Error, new List<String>{ALMJobServices.getToolName(ALMJobServices.ToolType.SCAN), currentInstance.record.Name})
                    ));
                }
                if (isButrActivated) {
                    messages.add( new PageMessage(
                        ApexPages.Severity.ERROR,
                        String.format(System.Label.Tool_Connection_Error, new List<String>{ALMJobServices.getToolName(ALMJobServices.ToolType.AUTOMATED_TESTING), currentInstance.record.Name})
                    ));
                }
            }
        }

        if (checkSightlineAuth) {
            Instances__c almInstance = InstanceServices.almInstance;
            Auth_User__c almAuth = (almInstance == null) ? null : OAuthServices.getAuthUserForTools(almInstance.Id);

            if (almAuth == null) {
                messages.add( new PageMessage(
                    ApexPages.Severity.WARNING,
                    System.Label.Scan_ALM_Settings_error + settingsLinkHTML
                ));
            } else if (!almAuth.Is_Refresh_Token_Valid__c) {
                messages.add( new PageMessage(
                    ApexPages.Severity.ERROR,
                    String.format(System.Label.Tool_Connection_Error, new List<String>{ALMJobServices.getToolName(ALMJobServices.ToolType.SCAN), almInstance.Name})
                    + settingsLinkHTML
                ));
            } else {
                messages.addAll(OAuthServices.checkSightlineAuthUser());
            }
        }

        return messages;
    }
}