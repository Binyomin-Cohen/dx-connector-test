public with sharing class VCRepoSyncRequest {
    public String clientId;
    public String clientSecret;
    public String sightlineRefreshToken;
    public String sightlineEndpoint;
    public String orgId;
    public List<VCRepoSyncDetails> reposToSync;

    public VCRepoSyncRequest(String clientId, String clientSecret, String sightlineRefreshToken, String sightlineEndpoint, String orgId,
            List<VCRepoSyncDetails> reposToSync) {
        this.clientId = clientId;
        this.clientSecret = clientSecret;
        this.sightlineRefreshToken = sightlineRefreshToken;
        this.sightlineEndpoint = sightlineEndpoint + VCServices.SOAP_ENDPOINT;
        this.orgId = orgId;
        this.reposToSync = reposToSync;
    }

    public class VCRepoSyncDetails {
        public String almJobId;
        public String repoId;
        public String repoUrl;
        public Long syncDateFrom;

        public String publicKey;
        public String privateKey;
        public String passPhrase;

        public VCRepoSyncDetails(String almJobId, String repoId, String repoUrl, Long syncDateFrom,
                String publicKey, String privateKey, String passPhrase) {
            this.repoUrl = repoUrl;
            this.repoId = repoId;
            this.syncDateFrom = syncDateFrom;
            this.almJobId = almJobId;
            this.publicKey = publicKey;
            this.privateKey = privateKey;
            this.passPhrase = passPhrase;
        }
    }
}
