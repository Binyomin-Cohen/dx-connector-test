public with sharing class VCControllerExt {
    public Boolean userHasPermission {get; set;}
    public Boolean userHasExistingKeypair {get; set;}
    public String backlogItemId {get; set;}

    public VCControllerExt(ApexPages.StandardController controller) {
        userHasPermission = new VCPermissions().hasPermission() == PermissionServices.PermissionLevel.FULL;
        userHasExistingKeypair = SSHServices.userHasExistingKeypair(UserInfo.getUserId());
        backlogItemId = ApexPages.currentPage().getParameters().get('backlogId');
    }

    @AuraEnabled
    public static String validateGitConnection(String vcRepositoryId) {
        if (!(new VCPermissions().hasPermission() == PermissionServices.PermissionLevel.FULL)) {
            throw new AuraHandledException(System.Label.Permissions_Error);
        }

        try {
            VCServices.GitListResponse response = VCServices.validateGitConnection(UserInfo.getUserId(), vcRepositoryId);
            return JSON.serialize(response);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static List<VCRepository> loadVCReposWithValidationsForUser() {
        return VCServices.loadVCReposWithValidationsForUser();
    }

    @AuraEnabled
    public static List<VCRepository> loadVCRepoWithValidationsForUser(Id repoId) {
        return VCServices.loadVCReposWithValidationsForUser(repoId);
    }

    @AuraEnabled
    public static String retrievePublicKey() {
        if (!(new SSHPermissions().hasPermission() == PermissionServices.PermissionLevel.FULL)) {
            throw new AuraHandledException(System.Label.Permissions_Error);
        }

        try {
            return SSHServices.retrievePublicKey(UserInfo.getUserId());
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static void generateKeypair() {
        if (!(new SSHPermissions().hasPermission() == PermissionServices.PermissionLevel.FULL)) {
            throw new AuraHandledException(System.Label.Permissions_Error);
        }

        try {
            SSHServices.generateKeypair(UserInfo.getUserId());
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

}