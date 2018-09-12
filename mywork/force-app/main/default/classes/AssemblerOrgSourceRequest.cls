public virtual with sharing class AssemblerOrgSourceRequest extends AssemblerRequest {
    public String sourceRefreshToken;
    public String sourceEndpoint;

    public AssemblerOrgSourceRequest(Build__c build, Auth_User__c sourceOAuth, Auth_User__c targetOAuth,
        Boolean skipTargetBackup) {

        super(build, targetOAuth, skipTargetBackup);

        if (sourceOAuth != null) {
            this.sourceRefreshToken = sourceOAuth.Refresh_Token__c;
            this.sourceEndpoint = sourceOAuth.Instance_URL__c + SOAP_ENDPOINT;
        }
    }
}