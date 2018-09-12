public with sharing class DXController {

    public static final String UNAUTHORIZED_DEV_HUB_MSG =
         'Please select your dev hub instance and confirm that it is authorized.';
    public static String SCRATCH_REQUEST_ENDPOINT = ALMRestServices.WEB_SERVICE_URL + '/dx/scratch-org/command';

    public String backlogItemId {get; set;}
    public String backlogItemName {get; set;}
    public String namespace {get; set;}

    public DXController(ApexPages.StandardController sc) {
        namespace = SObjectServices.CURRENT_NAMESPACE;
        sc.addFields(new List<String> {'Name'});
        backlogItemId = sc.getId();
        backlogItemName = (String)sc.getRecord().get('Name');
    }

    @AuraEnabled
    public static List<Instances__c> getInstances() {
        return InstanceServices.getAllInstances();
    }

    @AuraEnabled
    public static String getDevHubOrgId() {
        return User_Preferences__c.getInstance().Default_Dev_Hub_Instance_Id__c;
    }

    public static Instances__c getDevHubOrg() {
        return InstanceServices.getInstance(getDevHubOrgId());
    }

    @AuraEnabled
    public static void setDevHubOrg (String devHubInstanceId) {
        User_Preferences__c preferences = User_Preferences__c.getInstance();
        preferences.Default_Dev_Hub_Instance_Id__c = devHubInstanceId;
        upsert preferences;
    }

    private static Auth_User__c getAuthUserOfDevHubOrg() {
        Id devHubId = getDevHubOrgId();
        if (String.isEmpty(devHubId)) {
            throw new ALMException(UNAUTHORIZED_DEV_HUB_MSG);
        }

        Auth_User__c authUser = OAuthServices.getAuthUser(devHubId, false);
        if (authUser == null) {
            throw new ALMException(UNAUTHORIZED_DEV_HUB_MSG);
        }
        OAuthRequest request = new OAuthRequest();
        List<Auth_User__c> authUsers = new List<Auth_User__c>();
        authUsers.add(authUser);
        List<Auth_User__c> refreshedAuths = request.reauthorize(authUsers, true);
        return refreshedAuths[0];
    }

    @AuraEnabled
    public static List<ScratchOrgModel> getScratchOrgs(String backlogItemId) {
        List<ScratchOrgModel> scratchOrgs = new List<ScratchOrgModel>();
        for (Scratch_Org__c scratchOrg : [ SELECT Id, CreatedById, Backlog_Item__c, Description__c, Name
            FROM Scratch_Org__c 
            WHERE Backlog_Item__c = :backlogItemId
            ORDER BY CreatedDate DESC]) {
            
            scratchOrgs.add(new ScratchOrgModel(scratchOrg));
        }
        return scratchOrgs;
    }
 
    @AuraEnabled
    public static List<Scratch_Org_Definition__c> getScratchOrgDefinitions() {
        return [SELECT Id, Name FROM Scratch_Org_Definition__c ORDER BY Name ASC];
    }

    @AuraEnabled
    public static String createScratchOrgRecord(String name, String backlogItemId, 
        String vcRepositoryId, String repositoryLocation, String scratchOrgDefId, Double durationDays, String parentBranchName) {
    
        Scratch_Org__c scratchOrg = new Scratch_Org__c(
            Name = name, 
            VC_Repository__c = vcRepositoryId,
            Repository_Location__c = repositoryLocation,
            Backlog_Item__c = backlogItemId,
            Scratch_Org_Definition__c = scratchOrgDefId,
            Duration_Days__c = Integer.valueOf(durationDays),
            Parent_Branch_Name__c = parentBranchName
        );
        insert scratchOrg;
        return scratchOrg.Id;
    }

    @AuraEnabled
    public static void createScratchOrg(String scratchOrgId) {
        List<Scratch_Org__c> scratchOrgs = [
            SELECT Id, VC_Repository__c, Repository_Location__c, Duration_Days__c, Parent_Branch_Name__c,
                Scratch_Org_Definition__r.Admin_Email__c, Scratch_Org_Definition__r.Country__c,
                Scratch_Org_Definition__r.Description__c, Scratch_Org_Definition__r.Disabled_Org_Preferences__c,
                Scratch_Org_Definition__r.Edition__c, Scratch_Org_Definition__r.Enabled_Org_Preferences__c,
                Scratch_Org_Definition__r.Features__c, Scratch_Org_Definition__r.Has_Sample_Data__c,
                Scratch_Org_Definition__r.Language__c, Scratch_Org_Definition__r.Org_Name__c,
                Scratch_Org_Definition__r.Username__c
                FROM Scratch_Org__c
                WHERE Id = :scratchOrgId];

        Scratch_Org__c scratchOrg;
        if (scratchOrgs.size() > 0) {
          scratchOrg = scratchOrgs[0];
        } else {
            throw new AuraHandledException('An error occurred when constructing the request');
        }

        try {
            Auth_User__c devHubAuth = getAuthUserOfDevHubOrg();
            DXCreateScratchOrgRequest scratchRequest = new DXCreateScratchOrgRequest(
                devHubAuth.Instance_URL__c, devHubAuth.Refresh_Token__c, scratchOrg,
                 scratchOrg.Scratch_Org_Definition__r);
            String requestBody = JSON.serialize(scratchRequest);
            makeCreateScratchCallout(requestBody);
        } catch (ALMException ae) {
            throw new AuraHandledException(ae.getMessage());
        }
    }

    @AuraEnabled
    public static Scratch_Org__c getScratchOrgById(String scratchOrgId) {
      return [
          SELECT VC_Repository__r.Name, Repository_Location__c 
          from Scratch_Org__c
          WHERE Id = :scratchOrgId
          LIMIT 1
      ];
    }

    @AuraEnabled
    public static String sendDxGitDiffRequest(String scratchOrgId, Id vcRepoId, String branch) {
        List<Scratch_Org__c> scratchOrgs = [SELECT Id, VC_Repository__c, Repository_Location__c
                                            FROM Scratch_Org__c
                                            WHERE Id = :scratchOrgId];

        Scratch_Org__c scratchOrg;
        if (scratchOrgs.size() > 0) {
          scratchOrg = scratchOrgs[0];
        } else {
            throw new AuraHandledException('An error occurred when constructing the request');
        }

        Scratch_Org_Info__c soInfo = Scratch_Org_Info__c.getValues(scratchOrgId);
        String sfdxAuthUrl = soInfo.SFDX_Auth_URL__c;

        DxGitDiffRequest gitDiffRequest = new DxGitDiffRequest(scratchOrgId,
            scratchOrg.VC_Repository__c, scratchOrg.Repository_Location__c, sfdxAuthUrl
        );
        String requestBody = JSON.serialize(gitDiffRequest);
        try {
            ALMRestServices.makePostRequest(SCRATCH_REQUEST_ENDPOINT, requestBody);
            return 'success';
        } catch(Exception ex) {
            throw new AuraHandledException('An error occurred sending the request');
        }
    }

    @AuraEnabled
    public static String sendDxGitCommitRequest(String scratchOrgId, Id vcRepoId, String branch,
                                                List<String> componentPaths, String commitMessage) {

        List<Scratch_Org__c> scratchOrgs = [SELECT Id, VC_Repository__c, Repository_Location__c
                                            FROM Scratch_Org__c
                                            WHERE Id = :scratchOrgId];

        Scratch_Org__c scratchOrg;
        if (scratchOrgs.size() > 0) {
          scratchOrg = scratchOrgs[0];
        } else {
            throw new AuraHandledException('An error occurred when constructing the request');
        }

        Scratch_Org_Info__c soInfo = Scratch_Org_Info__c.getValues(scratchOrgId);
        String sfdxAuthUrl = soInfo.SFDX_Auth_URL__c;

        DxGitCommitRequest request = new DxGitCommitRequest(scratchOrgId,
            scratchOrg.VC_Repository__c, scratchOrg.Repository_Location__c, sfdxAuthUrl, componentPaths, commitMessage
        );
        String requestBody = JSON.serialize(request);
        try {
            ALMRestServices.makePostRequest(SCRATCH_REQUEST_ENDPOINT, requestBody);
            return 'success';
        } catch(Exception ex) {
            throw new AuraHandledException('An error occurred sending the request');
        }
    }

    @Future(callout=true)
    public static void makeCreateScratchCallout(String requestBody) {
        try {
            ALMRestServices.makePostRequest(SCRATCH_REQUEST_ENDPOINT, requestBody);
        } catch(Exception ex) {
            ALMLogServices.error(ex, ALMLogServices.Application.DX_SCRATCH);
        }
    }

    @AuraEnabled
    public static String getLoginUrlForScratchOrg(String scratchOrgId) {
        return ScratchOrgServices.getLoginUrl(scratchOrgId);
    }

    public class ScratchOrgModel {
        @AuraEnabled
        public String id;
        @AuraEnabled
        public String name;
        @AuraEnabled
        public Boolean isLoginable;
          
        public ScratchOrgModel(Scratch_Org__c scratchOrg) {
            this.id = scratchOrg.Id;
            this.name = scratchOrg.Name;
            //TODO: in the future this should take org expiration into account
            this.isLoginable = scratchOrg.CreatedById == UserInfo.getUserId();
        }
    }

}
