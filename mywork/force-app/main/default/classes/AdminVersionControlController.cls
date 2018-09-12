public with sharing class AdminVersionControlController {

    public static final String NEW_REPO_IDENTIFIER = 'new';
    public Boolean hasPermissions {get; set;}
    public String repoId {get; set;}
    public String repoName {get; set;}
    public String namespace {get; set;}

    public AdminVersionControlController() {
        hasPermissions = ALMSettings__c.getOrgDefaults().VCS_Integration_Enabled__c;
        if (!hasPermissions) {
            ApexPages.addMessage(new ApexPages.Message(
                ApexPages.Severity.ERROR,
                System.Label.Permissions_Error
            ));
        }
        setPageContext();
        
    }
    
    @TestVisible
    private void setPageContext() {
        String urlRepoId = ApexPages.currentPage().getParameters().get('id');
        if (String.isBlank(urlRepoId) || urlRepoId == NEW_REPO_IDENTIFIER) {
            if( urlRepoId == NEW_REPO_IDENTIFIER ) {
                repoId = urlRepoId;
            }
        } else {
	        VC_Repository__c repoFromPageParams = VCServices.getVCRepoRecord( urlRepoId );
	        if ( repoFromPageParams != null ) {
                repoId = repoFromPageParams.Id;
                repoName = repoFromPageParams.Name;
	        }
        }
        namespace = SObjectServices.CURRENT_NAMESPACE;
    }
    
    @AuraEnabled
    public static List<VCRepository> getExistingRepositories() {
        return VCServices.getVCRepositories();
    }

    @AuraEnabled
    public static List<String> getSourceFormatOptions(){
        return SObjectServices.getPicklistValues(VC_Repository__c.Source_Format__c.getDescribe());
    }
    
    @AuraEnabled
    public static VCRepository getExistingRepository( String repoId ) {
        return VCServices.getVCRepository( repoId );
    }

    @AuraEnabled
    public static Map<String, String> getRepositoryHosts() {
        return SObjectServices.getPicklistValueMap(VC_Repository__c.Host__c.getDescribe());
    }

    @AuraEnabled
    public static VCRepository upsertRepositoryWithALMJob(String repoRepresentation, Boolean destroyJob) {
        try {
            return VCServices.upsertRepositoryWithAlmJob(repoRepresentation, destroyJob);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

}
