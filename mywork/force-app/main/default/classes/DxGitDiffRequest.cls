public with sharing class DxGitDiffRequest extends BaseRequest {
    public String pmScratchOrgId;
    public VersionControlSource versionControlSource;
    public String sfdxAuthUrl;

    public DxGitDiffRequest() {
        super();
    }

    // TODO: mirror Java - create DXJob class
    public DxGitDiffRequest(String pmScratchOrgId, String vcRepositoryId, String repositoryLocation, String sfdxAuthUrl) {
        super();
        this.pmScratchOrgId = pmScratchOrgId;
        this.sfdxAuthUrl = sfdxAuthUrl;

        // taken from VCCommitRequest - pull into common method
        List<VC_Repository__c> repos = [
            SELECT Repository_URL__c, SFDC_Metadata_Path__c, Source_Format__c
                FROM VC_Repository__c
                WHERE Id = :vcRepositoryId ];
        VC_Repository__c repo;
        if (repos.size() > 0) {
            repo = repos[0];
        } else {
            throw new ALMException(System.Label.VC_Repository_Retrieval_Error);
        }

        if (String.isBlank(repo.Repository_URL__c)) {
            throw new ALMException(VCServices.NO_REPOSITORY_URL_ERROR);
        }

        this.versionControlSource = new VersionControlSource(repo, repositoryLocation);
    }

}
