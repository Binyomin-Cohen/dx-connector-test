public with sharing class ScratchOrgServices {

    public static final String FRONT_DOOR_URL = '/secur/frontdoor.jsp?sid=';

    public static String getLoginUrl(String scratchOrgId) {
        String url = null;
        Scratch_Org_Info__c soInfo = Scratch_Org_Info__c.getValues(scratchOrgId);
        //TODO: write test and move to another method
        List<Scratch_Org__c> scratchOrgs = [SELECT Id FROM Scratch_Org__c 
            WHERE Id = :scratchOrgId
             AND CreatedById = :UserInfo.getUserId()];

        if(soInfo != null && !scratchOrgs.isEmpty()) {
            url = soInfo.Instance_URL__c + FRONT_DOOR_URL + getFreshAccessToken(soInfo);
        }
        return url;

    }
        public static String getFreshAccessToken(Scratch_Org_Info__c scratchOrgInfo) {
        String accessToken = scratchOrgInfo.Access_Token__c;

        OAuthServices.AppSettings appSettings = new OAuthServices.AppSettings(
            OAuthServices.getAppSettings().callBackURL,
            getClientIdFromAuthUrl(scratchOrgInfo),
            getConsumerSecretFromAuthUrl(scratchOrgInfo));

        //TODO the following should really be the scratchOrgInfo.Instance_URL__c, but we would then have to be able to add that to the remote site settings
        String customLoginUrl = 'https://test.salesforce.com';

        OauthRequest oauthReq = new OAuthRequest(appSettings, customLoginUrl);

        Auth_User__c authUser = new Auth_User__c(
                    Access_Token__c = accessToken, Refresh_Token__c = getRefreshTokenFromAuthUrl(scratchOrgInfo)
        );
        List<Auth_User__c> authUsers = new List<Auth_User__c>{authUser};
        authUsers = oauthReq.reauthorize(authUsers, false);
        String freshAccessToken = authUsers[0].Access_Token__c;
        scratchOrgInfo.Access_Token__c = freshAccessToken;
        update scratchOrgInfo;
        return freshAccessToken;
    }

    //auth url is in the format force://CLIENT_ID:CONSUMER_SECRET:REFRESH_TOKEN@flow-nosoftware-5934-dev-ed.cs10.my.salesforce.com

    public static String getRefreshTokenFromAuthUrl(Scratch_Org_Info__c scratchOrgInfo) {
        String authUrl = scratchOrgInfo.SFDX_Auth_URL__c;
        List<String> parsed = authUrl.split(':');
        return parsed.size() == 4 ? parsed[3].substring(0, parsed[3].indexOf('@')) : '';

    }

    public static String getClientIdFromAuthUrl(Scratch_Org_Info__c scratchOrgInfo) {
        String authUrl = scratchOrgInfo.SFDX_Auth_URL__c;
        List<String> parsed = authUrl.split(':');
        Integer START_INDEX_OF_CLIENT_ID = 2;
        return (parsed.size() == 4 && parsed[1].length() >START_INDEX_OF_CLIENT_ID )?
            parsed[1].substring(START_INDEX_OF_CLIENT_ID): '';
    }

    public static String getConsumerSecretFromAuthUrl(Scratch_Org_Info__c scratchOrgInfo) {
        String authUrl = scratchOrgInfo.SFDX_Auth_URL__c;
        List<String> parsed = authUrl.split(':');
        return parsed.size() == 4 ? parsed[2].substring(0, parsed[2].length()): '';
    }
}
