public virtual with sharing class BaseRequest {

    public static final String SOAP_ENDPOINT = '/services/Soap/u/42.0';

    public String sightlineServerURL;
    public String sightlineEndpoint;
    public String clientId;
    public String clientSecret;
    public String organizationId;
    public String sightlineRefreshToken;

    public BaseRequest() {
        Auth_User__c sightlineAuthUser = OAuthServices.getSightlineAuthUser();
        if (sightlineAuthUser != null) {
            this.sightlineRefreshToken = sightlineAuthUser.Refresh_Token__c;
        	this.sightlineServerURL = sightlineAuthUser.Instance_URL__c;
        	this.sightlineEndpoint =  sightlineServerURL + SOAP_ENDPOINT;
        }

        OAuthServices.AppSettings settings = OAuthServices.getAppSettings();
        this.clientId = settings.consumerKey;
        this.clientSecret = settings.consumerSecret;
        this.organizationId = UserInfo.getOrganizationId();

    }
}