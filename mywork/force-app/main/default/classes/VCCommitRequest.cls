public with sharing class VCCommitRequest extends BaseRequest {

    public String vcCommitId;
    public String commitOwner;
    public String commitMessage;

    public VersionControlSource versionControlSource;

    public String sourceRefreshToken;
    public String sourceEndpoint;

    public List<List<String>> components;
    public List<ProfilePermissions> profiles;
    public List<List<String>> destructiveChanges;

    public VCCommitRequest(VC_Commit__c vcCommit, Auth_User__c sourceAuthUser) {
        super();
        this.vcCommitId    = vcCommit.Id;

        List<VC_Repository__c> repos = [
            SELECT Repository_URL__c, SFDC_Metadata_Path__c, Source_Format__c
                FROM VC_Repository__c
                WHERE Id = :vcCommit.VC_Repository__c ];
        VC_Repository__c repo;
        if (repos.size() > 0) {
            repo = repos[0];
        } else {
            throw new ALMException(System.Label.VC_Repository_Retrieval_Error);
        }

        if (String.isBlank(repo.Repository_URL__c)) {
            throw new ALMException(VCServices.NO_REPOSITORY_URL_ERROR);
        }

        this.commitMessage = vcCommit.Commit_Message__c;
        this.commitOwner = vcCommit.CreatedBy.Username;

        this.sourceRefreshToken = sourceAuthUser.Refresh_Token__c;
        this.sourceEndpoint     = sourceAuthUser.Instance_URL__c + SOAP_ENDPOINT;

        if (String.isEmpty(sightlineRefreshToken)) {
            throw new ALMException(System.Label.Sightline_Instance_Not_Authorized);
        } 

        this.components = new List<List<String>>();
        this.destructiveChanges = new List<List<String>>();
        this.profiles = new List<ProfilePermissions>();

        this.versionControlSource = new VersionControlSource(repo, vcCommit.Branch_Name__c);

        if (String.isBlank(versionControlSource.publicKey) 
            || String.isBlank(versionControlSource.privateKey) 
            || String.isBlank(versionControlSource.passphrase)) {
            throw new ALMException(System.Label.SSH_User_Key_Retrieval_Error);
        }

        loadBacklogComponents(vcCommit.Backlog_Item__c, vcCommit.Backlog_Components__c);
    }

    private void loadBacklogComponents(String backlogId, String rawBacklogComponentIds) {
        components.add( new List<String>{ AssemblerRequest.COMPONENT_HEADER_NAME, AssemblerRequest.COMPONENT_HEADER_TYPE, AssemblerRequest.COMPONENT_HEADER_PARENT,'Profile', 'Profile Permission' });
        destructiveChanges.add( new List<String>{ AssemblerRequest.COMPONENT_HEADER_NAME, AssemblerRequest.COMPONENT_HEADER_TYPE, AssemblerRequest.COMPONENT_HEADER_PARENT });
        List<AssemblerManifestRecord> allBacklogComponents = AssemblerServices.getManifest(null, new List<String>(), new List<String>(), new List<String>(), new List<String> {backlogId});
        Set<String> backlogComponentIds = new Set<String>(rawBacklogComponentIds.split(','));

        for (AssemblerManifestRecord bc : allBacklogComponents ) {
            String backlogComponentId = bc.getBuildComponent().Backlog_Component__c;
            if (backlogComponentIds.contains(backlogComponentId)) {
                if (bc.isDeletion) {
                    destructiveChanges.add(new List<String> { bc.getName(), bc.getType(), bc.getParent() });
                } else {
                    components.add( new List<String> { bc.getName(), bc.getType(), bc.getParent(), '', '0' });
                }
            }
        }
    }

}
