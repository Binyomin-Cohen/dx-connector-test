public with sharing class AdminAlmSettingsController extends OAuthController {
    public static final String ALM_INSTANCE_DEFAULT_NAME = 'Sightline Instance';

    @TestVisible
    private static final String PAGE_STATE_TOKEN = 'PageState AdminAlmSettings';
    private static final Integer NAME_MAX_SIZE = 40;

    public InstanceModel almInstanceModel {get; set;}
    public List<PageMessage> pageMessages {get; set;}
    public Boolean hasSaveErrors {get; set;}
    public Boolean hasPermissions {get; set;}

    public Boolean isPageRestored {get; set;}

    public AdminAlmSettingsController() {
        Instances__c almInstance = InstanceServices.almInstance;
        if (almInstance == null) {
            almInstance = new Instances__c(Name=ALM_INSTANCE_DEFAULT_NAME, Is_Alm_Instance__c=true);
        }
        almInstanceModel = new InstanceModel(almInstance);

        initialPageStateMap = getCurrentPageStateMap();
        restorePageState();

        hasSaveErrors = false;
        isAuthValid();
        hasPermissions = PermissionServices.checkPagePermissions(new AdminSettingsPermissions()) == PermissionServices.PermissionLevel.FULL;
    }

    public override void loadState(Map<String, Object> stateMap) {
        isAuthValid();
    }

    public override String getInstanceIdToAuthorize() {
        return almInstanceModel.record.Id;
    }

    public void save() {
        if(String.isBlank(almInstanceModel.record.Name) ||
            String.isBlank(almInstanceModel.record.Type__c))
        {
            addGenericPageError('Instance name and Type are required.');
            return;
        }

        if(almInstanceModel.record.Name.length() > NAME_MAX_SIZE) {
            addGenericPageError('Instance name cannot be more than ' + NAME_MAX_SIZE + ' characters.');
            return;
        }

        try {
            upsert almInstanceModel.record;

            expirePageState();
            initialPageStateMap = getCurrentPageStateMap();
        } catch (DMLException de) {
            ApexPages.addMessages(de);
            hasSaveErrors = true;
            return;
        }

        hasSaveErrors = false;
    }

    public void checkAuthUser() {
        if (isAuthValid()) {
            if (pageMessages == null) {
                pageMessages = new List<PageMessage>();
            }
            pageMessages.addAll(OAuthServices.checkSightlineAuthUser());
        }
    }

    @TestVisible
    protected override Map<String, Object> getCurrentPageStateMap() {
        return new Map<String, Object>{
            'name' => (!String.isBlank(almInstanceModel.record.Name) ? almInstanceModel.record.Name : null),
            'type' => (!String.isBlank(almInstanceModel.record.Type__c) ? almInstanceModel.record.Type__c : null),
            'domain' => (!String.isBlank(almInstanceModel.record.Custom_Domain__c) ? almInstanceModel.record.Custom_Domain__c : null)
        };
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
                almInstanceModel.record.Name = String.valueOf(pageStateMap.get('name'));
            }
            if (pageStateMap.containsKey('type')) {
                almInstanceModel.record.Type__c = String.valueOf(pageStateMap.get('type'));
            }
            if (pageStateMap.containsKey('domain')) {
                almInstanceModel.record.Custom_Domain__c = String.valueOf(pageStateMap.get('domain'));
            }
        }
    }

    /**
    * Side effect: Resets pageMessages.
    */
    private Boolean isAuthValid() {
        pageMessages = new List<PageMessage>();

        Instances__c almInstance = InstanceServices.almInstance;
        Auth_User__c almAuth = (almInstance == null) ? null : OAuthServices.getAuthUserForTools(almInstance.Id);

        if (almAuth == null) {
            return false;
        }

        if (!almAuth.Is_Refresh_Token_Valid__c) {
            pageMessages.add(new PageMessage(
                ApexPages.Severity.ERROR,
                'There is a connection error to the Sightline Instance. Please review your Sightline Settings below.'
            ));
            return false;
        }

        return true;
    }

    private void addGenericPageError(String msg) {
        ApexPages.addMessage(new ApexPages.Message(
            ApexPages.Severity.ERROR,
            System.Label.Generic_Error + ': ' + msg
        ));
        hasSaveErrors = true;
    }
}