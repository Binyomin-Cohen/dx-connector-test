public with sharing class BacklogManagementHomeController {

    public Integer permissionLevel {get; private set;}
    public transient ALMPageMessages pageMsgs { get; set; }
    public String namespace {get; set;}
    public String defaultCustomBacklogId {
        get {
            if (defaultCustomBacklogId == null) {
                User_Preferences__c preference = User_Preferences__c.getValues(UserInfo.getUserId());
                if (preference == null) {
                    defaultCustomBacklogId = '';
                } else {
                    defaultCustomBacklogId = preference.Default_Custom_Backlog_Id__c;
                }
            }

            return defaultCustomBacklogId;
        }

        set;
    }

    public static String MASTER_BACKLOG_IDENTIFIER {
        get {
            if (MASTER_BACKLOG_IDENTIFIER == null) {
                MASTER_BACKLOG_IDENTIFIER = 'Master';
            }

            return MASTER_BACKLOG_IDENTIFIER;
        }

        set;
    }

    public static String MASTER_BACKLOG_RECORD_ID {
        get {
            return CustomBacklogServices.MASTER_BACKLOG_RECORD.Id;
        }

        set;
    }

    private final static String DUPLICATE_CUSTOM_BACKLOG_NAME_ERROR_MSG = 'Custom backlog already exist.';

    public BacklogManagementHomeController(){
        permissionLevel = PermissionServices.checkPagePermissions(new CustomBacklogPermissions()).ordinal();
        namespace = SObjectServices.getNameSpace();
    }

    private static List<CustomBacklogModel> getCustomBacklogModels(List<Custom_Backlog__c> customBacklogs){
        List<CustomBacklogModel> cbklgModels = new List<CustomBacklogModel>();
        for (Custom_Backlog__c cbklg : customBacklogs){
            CustomBacklogModel cbklgModel = new CustomBacklogModel(cbklg);
            if (cbklg.Universal__c) {
                setGlobalBacklogCounts(cbklgModel);
            }
            cbklgModels.add(cbklgModel);
        }
        return cbklgModels;
    }

    public static void setGlobalBacklogCounts(CustomBacklogModel cbklgModel) {
        Integer unprioritizedInt = 0;
        Set<String> inactiveStatuses = BacklogItemServices.getInactiveStatuses();
        List<Backlog__c> items = [SELECT Id, Priority__c, Name
                 FROM Backlog__c
                 WHERE Status__c NOT IN :inactiveStatuses
                 ORDER BY Priority__c NULLS FIRST LIMIT 1000];

        for (Backlog__c item: items) {
            if (item.Priority__c == null) {
                unprioritizedInt += 1;
            }
        }
        cbklgModel.unprioritizedItems = CustomBacklogModel.getCountAsString(unprioritizedInt);
        cbklgModel.totalItems = CustomBacklogModel.getCountAsString(items.size());
    }

    @ReadOnly
    @RemoteAction
    public static List<CustomBacklogModel> getAllCustomBacklogs() {
        Set<String> inactiveStatuses = BacklogItemServices.getInactiveStatuses();
        List<Custom_Backlog__c> currentCustomBacklogs = [
            SELECT Id, Name, Universal__c,
                (SELECT Id, Custom_Priority__c, Name
                 FROM Backlog_Items__r
                 WHERE Status__c NOT IN :inactiveStatuses
                 ORDER BY Custom_Priority__c NULLS FIRST LIMIT 1000)
            FROM Custom_Backlog__c ORDER BY Universal__c DESC, Name ASC LIMIT 500
        ];
        return getCustomBacklogModels(CustomBacklogServices.loadSortedCustomBacklogs(currentCustomBacklogs));
    }

    @RemoteAction
    public static void updateUserPreferences(String backlogId) {
        User_Preferences__c preference = User_Preferences__c.getInstance(UserInfo.getUserId());
        preference.Default_Custom_Backlog_Id__c = backlogId;

        try {
            upsert preference;
        } catch (DMLException e) {
            throw new ALMException('An error occured updating the User_Preferences__c custom setting: '+ e.getMessage() );
        }
    }

    @RemoteAction
    public static void updateUserSpecificSortState(String customBacklogIds) {
        if (PermissionServices.checkPagePermissions(new CustomBacklogPermissions()).ordinal() < PermissionServices.PermissionLevel.FULL.ordinal()) {
            return;
        }

        CustomBacklogServices.updateCustomBacklogSortState(customBacklogIds);
    }

    private static UpsertCustomBacklogResponse validateCustomBacklogName(String name){
        UpsertCustomBacklogResponse response = new UpsertCustomBacklogResponse();
        List<Custom_Backlog__c> customBacklogs = [Select Id From Custom_Backlog__c Where Name = :name];
        if (!customBacklogs.isEmpty()){
            response.isSuccess = false;
            response.isValid = false;
            response.errorMsg = DUPLICATE_CUSTOM_BACKLOG_NAME_ERROR_MSG;
            return response;
        }
        response.isValid = true;
        return response;
    }

    @RemoteAction
    public static UpsertCustomBacklogResponse createCustomBacklog(String name) {
        if (PermissionServices.checkPagePermissions(new CustomBacklogPermissions()).ordinal() < PermissionServices.PermissionLevel.FULL.ordinal()) {
            UpsertCustomBacklogResponse response = new UpsertCustomBacklogResponse();
            response.isSuccess = false;
            response.errorMsg = System.Label.Permissions_Error;

            return response;
        }

        UpsertCustomBacklogResponse response = validateCustomBacklogName(name);
        if (!response.isValid){
            return response;
        }
        try {
            Custom_Backlog__c customBacklog = new Custom_Backlog__c(Name = name);
            insert customBacklog;
            response.customBacklogId = customBacklog.Id;
            response.isSuccess = true;
        } catch (Exception e){
            response.isSuccess = false;
            response.errorMsg = e.getMessage();
        }
        return response;
    }

    @RemoteAction
    public static UpsertCustomBacklogResponse updateCustomBacklog(String customBacklogId, String name) {
        if (PermissionServices.checkPagePermissions(new CustomBacklogPermissions()).ordinal() < PermissionServices.PermissionLevel.FULL.ordinal()) {
            UpsertCustomBacklogResponse response = new UpsertCustomBacklogResponse();
            response.isSuccess = false;
            response.errorMsg = System.Label.Permissions_Error;

            return response;
        }

        UpsertCustomBacklogResponse response = validateCustomBacklogName(name);
        if (!response.isValid){
            return response;
        }
        try {
            if(BacklogManagementHomeController.MASTER_BACKLOG_IDENTIFIER.equalsIgnoreCase(customBacklogId)) {
                customBacklogId = BacklogManagementHomeController.MASTER_BACKLOG_RECORD_ID;
            }
            Custom_Backlog__c customBacklog = new Custom_Backlog__c(Id=customBacklogId, Name = name);
            update customBacklog;
            response.customBacklogId = customBacklog.Id;
            response.isSuccess = true;
        } catch (Exception e){
            response.isSuccess = false;
            response.errorMsg = e.getMessage();
        }
        return response;
    }

    public class UpsertCustomBacklogResponse {
        public String customBacklogId;
        public Boolean isSuccess;
        public Boolean isValid;
        public String errorMsg;
        public UpsertCustomBacklogResponse(){

        }
    }
}