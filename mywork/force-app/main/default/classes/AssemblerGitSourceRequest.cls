public virtual with sharing class AssemblerGitSourceRequest extends AssemblerRequest {

    public VersionControlSource versionControlSource;

    public AssemblerGitSourceRequest(Build__c build, Auth_User__c targetOAuth, VC_Repository__c repository,
     Boolean skipTargetBackup) {
        super(build, targetOAuth, skipTargetBackup);
        this.versionControlSource = new VersionControlSource(repository, build.Source_Repository_Location__c);
    }
}