public with sharing class AssemblerJenkinsBuildRequest extends AssemblerGitSourceRequest {
    public AssemblerJenkinsBuildRequest(Build__c build, Auth_User__c targetOAuth, VC_Repository__c repository,
     Boolean skipTargetBackup) {
        super(build, targetOAuth, repository, skipTargetBackup);
    }

    /**
    *   Retrieves all components documented against the Release
    *   @param  build   the build related to the Release__c to retreive components from
    */
    protected override List<AssemblerManifestRecord> retrieveComponentsToBuild(Build__c build) {
        List<AssemblerManifestRecord> componentsToBuild = AssemblerServices.getManifest(build.Release__c);
        componentsToBuild.addAll(AssemblerServices.getDocumentedProfiles(build.Release__c));
 
        return componentsToBuild;
    }

}
