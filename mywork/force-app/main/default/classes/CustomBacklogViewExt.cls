public with sharing class CustomBacklogViewExt {

    private final Custom_Backlog__c backlog;

    public CustomBacklogViewExt(ApexPages.StandardController stdController) {
        this.backlog = (Custom_Backlog__c) stdController.getRecord();
    }

    public PageReference doRedirect() {
        PageReference backlogManagementPage = Page.BacklogManagement;
        backlogManagementPage.setRedirect(true);

        Boolean hasCustomBacklogPermissions = (new CustomBacklogPermissions()).hasPermission() == PermissionServices.PermissionLevel.FULL;
        if (hasCustomBacklogPermissions) {
            backlogManagementPage.getParameters().put(BacklogManagementExt.CUSTOM_BACKLOG_ID_PARAM, backlog.Id);
        }
        return backlogManagementPage;
    }
}
