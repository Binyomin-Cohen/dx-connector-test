public with sharing class VersionControlSource {
    //SSH Data
    public String publicKey;
    public String privateKey;
    public String passphrase;

    public String repoId;
    public String repoUrl;
    /*The branch or tag in the repository*/
    public String repoLocation;
    public String sfdcMetadataPath;
    public String sourceFormat;
    public static String DX_FORMAT_LABEL = 'Salesforce DX';
    public static String DX = 'DX';
    public static String METADATA = 'METADATA';

    /**
    * @throws ALMException  when there are no SSH keys for the current user
    */
    public VersionControlSource(VC_Repository__c repository, String location) {
        Map<String, String> secrets = SSHServices.retrieveKeysAndPassphrase(UserInfo.getUserId());
        this.publicKey = secrets.get(SSHServices.PUBLIC_KEY);
        this.privateKey = secrets.get(SSHServices.PRIVATE_KEY);
        this.passphrase = secrets.get(SSHServices.PASS_PHRASE);

        this.repoId = repository.Id;
        this.repoUrl = repository.Repository_URL__c;
        this.repoLocation = location;
        this.sfdcMetadataPath = repository.SFDC_Metadata_Path__c;
        this.sourceFormat = getSourceFormatForTools(repository.Source_Format__c);
    }
    
    private String getSourceFormatForTools(String sformat) {
        if (DX_FORMAT_LABEL.equals(sformat)) {
            return DX;
        } else {
            return METADATA;
        }
    }
}
