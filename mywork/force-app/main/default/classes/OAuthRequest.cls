public with sharing class OAuthRequest {
    public static final String AUTH_GRANT_TYPE_CODE='authorization_code';
    public static final String REFRESH_GRANT_TYPE_CODE='refresh_token';

    public static final String OAUTH_USERINFO_URL = '/services/oauth2/userinfo?oauth_token=';
    public static final String OAUTH_TOKEN_URL='/services/oauth2/token';
    public static final String OAUTH_CODE_END_POINT_URL='/services/oauth2/authorize';

    public static final Integer SUCCESS_STATUS_CODE = 200;
    public static final Integer ERROR_FORBIDDEN_STATUS_CODE = 403;
    public static final Integer ERROR_NOT_FOUND_STATUS_CODE = 404;
    public static final Integer ERROR_NOT_ACCEPTABLE_STATUS_CODE = 406;

    public static final String ERROR_NOT_FOUND_BAD_ID='Bad_Id';
    public static final String ERROR_NOT_FOUND_INACTIVE='Inactive';
    public static final String ERROR_NOT_FOUND_NO_ACCESS='No_Access';
    public static final String ERROR_NOT_FOUND_NO_SITE_ENDPOINT='No_Site_Endpoint';
    public static final String ERROR_NOT_FOUND_INTERNAL_ERROR='Internal Error';

    public static final String REAUTHORIZE_MAX_CALLOUTS_MSG = 'Unable to reauthorize all Auth_User__c records. ' +
        'The max number of callouts has been reached: ' + Limits.getLimitCallouts();
    private String customLoginUrl;    

    @testVisible
    private static Map<Integer, Set<String>> REQUESTS_TO_RETRY = new Map<Integer, Set<String>>{
        ERROR_FORBIDDEN_STATUS_CODE => null,
        ERROR_NOT_FOUND_STATUS_CODE => new Set<String>{ERROR_NOT_FOUND_BAD_ID, ERROR_NOT_FOUND_INACTIVE, ERROR_NOT_FOUND_NO_ACCESS}
    };

    private List<String> oAuthErrorResponses;
    private OAuthServices.AppSettings appSettings;
    private Map<String, String> state;

    public OAuthRequest() {
        appSettings = OAuthServices.getAppSettings();
        state = new Map<String, String>();
    }

    public OAuthRequest(OAuthServices.AppSettings appSettings, String customLoginUrl) {
        this.appSettings = appSettings;
        this.customLoginUrl = customLoginUrl;
        state = new Map<String, String>();
    }

    @testVisible
    private static Boolean shouldRetryAuth(Integer statusCode, String responseBody){
        if (OAuthRequest.REQUESTS_TO_RETRY.containsKey(statusCode)){
            if (OAuthRequest.REQUESTS_TO_RETRY.get(statusCode) == null || OAuthRequest.REQUESTS_TO_RETRY.get(statusCode).contains(responseBody)){
                return true;
            }
        }
        return false;
    }

    public void setState(String url, Map<String, String> stateMap) {
        state = new Map<String, String>();
        if (stateMap != null) {
            state.putAll(stateMap);
        }
        for(String key : stateMap.keySet()) {
            String value = stateMap.get(key);
            state.put(key, EncodingUtil.urlEncode(value, 'UTF-8'));
        }

        List<String> urlParts = url.split('\\?', 2);
        if (urlParts.size() > 1) {
            url = urlParts[0] + '?' + EncodingUtil.urlEncode(urlParts[1], 'UTF-8');
        }
        state.put('origin_url', url);
    }

    public Map<String, String> getState() {
        return state;
    }

    /**
    *   Gets the OAuth authorization url
    *   @param loginEndpoint    - The salesforce login endpoint - https://test|login.salesforce.com or a custom domain
    */
    public String getAuthorizationUrl(String loginEndpoint) {

        Boolean showPopup = false;
        return getAuthorizationUrl(loginEndpoint, showPopup);
    }

    public String getAuthorizationUrl(String loginEndpoint, Boolean showPopup) {

        String oAuthEndpoint = loginEndpoint + OAUTH_CODE_END_POINT_URL;
        String url = oAuthEndpoint +
                    +'?redirect_uri='+appSettings.callBackURL
                    +'&response_type=code&client_id='+appSettings.consumerKey
                    +'&grant_type='+AUTH_GRANT_TYPE_CODE
                    +'&prompt=login%20consent'
                    +'&state='+JSON.serialize(state);
        url += showPopup ? '&display=popup' : '';
        return url;
    }

    public TokenResponse getAccessToken(String endPoint, String grantType, String code) {
        Http h = new Http();
        String codeParam;
        if(grantType.contains('refresh'))
        {
            codeParam = 'refresh_token='+code;
        }
        else
        {
            codeParam = 'code='+code;
        }

        String body=codeParam
                    +'&client_id='+appSettings.consumerKey
                    +'&client_secret='+appSettings.consumerSecret
                    +'&redirect_uri='+appSettings.callBackURL
                    +'&grant_type='+grantType;
        HttpRequest req = new HttpRequest();
        req.setEndpoint(endPoint);
        req.setHeader('Content-Type','application/x-www-form-urlencoded');
        req.setMethod('POST');
        req.setBody(body);

        try {
            HttpResponse res = h.send(req);
System.debug(res.getBody());
            return (TokenResponse)JSON.deserialize(res.getBody(), TokenResponse.class);
        } catch(Exception e) {
            System.debug(e);
            throw new ALMException(e.getMessage());
        }
    }

    public TokenResponse refreshAccessToken(Auth_User__c auth, String loginEndpoint) {
        String accessTokenEndpoint = loginEndpoint + OAUTH_TOKEN_URL;

        return getAccessToken(accessTokenEndpoint, REFRESH_GRANT_TYPE_CODE, auth.Refresh_Token__c);
    }



    private UserInfoResponse reauthorizeUser(Auth_User__c auth, Boolean doUpsert){
        Http http = new Http();
        String loginEndpoint = getLoginEndpoint(auth);

        UserInfoResponse response = new UserInfoResponse(false);

        try {
            HttpResponse res = http.send( getUserInfoRequest(auth.Access_Token__c, loginEndpoint) );

            if (res.getStatusCode() == SUCCESS_STATUS_CODE) {
                auth.Is_Refresh_Token_Valid__c = true;
                response = (UserInfoResponse)JSON.deserialize(res.getBody(), UserInfoResponse.class);
                response.isAuthorized = true;
            } else if (shouldRetryAuth(res.getStatusCode(), res.getBody())) {
                TokenResponse tokenResponse = refreshAccessToken(auth, loginEndpoint);

                res = http.send( getUserInfoRequest(tokenResponse.access_token, loginEndpoint) );

                if (res.getStatusCode() == SUCCESS_STATUS_CODE) {
                    response = (UserInfoResponse)JSON.deserialize(res.getBody(), UserInfoResponse.class);
                    response.isAuthorized = true;
                    OAuthServices.updateAuthUserFromResponse(tokenResponse, auth);
                } else {
                    auth.Is_Refresh_Token_Valid__c = false;
                }
                if (doUpsert){
                    OAuthServices.upsertAuthUser(tokenResponse, auth, auth.Is_For_Tools__c);
                }

            } else {
                auth.Is_Refresh_Token_Valid__c = false;
                oAuthErrorResponses.add(auth + ' - response - ' + res + '\n');
                if (doUpsert){
                    OAuthServices.upsertAuthUserRecord(auth);
                }
            }

        } catch(Exception e) {
            System.debug(e);
            ALMLogServices.error(e, ALMLogServices.Application.OAUTH);
            throw new ALMException(e.getMessage());
        }

        return response;
    }

    private void logOAuthErrors(Boolean doLogErrors){
        if (oAuthErrorResponses != null && !oAuthErrorResponses.isEmpty()){
            String errorMsg = 'Authentication Errors: ' + String.join(oAuthErrorResponses, '\n');
            ALMException loggedException = new ALMException(errorMsg);
            if (doLogErrors){
                ALMLogServices.error(loggedException, ALMLogServices.Application.OAUTH);
            } else {
                System.debug(loggedException);
            }
        }
    }

    /**
    *  Retrieve user info with the given authorization. If authorization is
    * expired, it will be renewed
    * @throws ALMException, DMLException
    */
    public UserInfoResponse getUserInfo(Auth_User__c auth) {

        oAuthErrorResponses = new List<String>();

        if (auth == null) {
            return new UserInfoResponse(false);
        }
        UserInfoResponse response = reauthorizeUser(auth, true);
        logOAuthErrors(true);
        return response;
    }

    public List<Auth_User__c> reauthorize(List<Auth_User__c> auths) {
        return reauthorize(auths, true);
    }

    /**
    * Ensures that all auths access tokens are valid and if not it will refresh the tokens.
    * @return The updated auth users
    * @throws ALMException, DMLException
    */
    public List<Auth_User__c> reauthorize(List<Auth_User__c> auths, Boolean updateAuths) {
        Http http = new Http();
        final Integer calloutsPerReauth = 2;

        oAuthErrorResponses = new List<String>();

        for (Auth_User__c auth : auths) {
            if (LimitServices.getRemainingCalloutsAvailable() < calloutsPerReauth) {
                throw new ALMException(REAUTHORIZE_MAX_CALLOUTS_MSG);
            }
            reauthorizeUser(auth, false);
        }

        logOAuthErrors(updateAuths);
        if(updateAuths) {
            update new List<Auth_User__c>(new Set<Auth_User__c>(auths));
        }

        return auths;
    }

    private String getLoginEndpoint(Auth_User__c auth) {
        if (customLoginUrl !=null ) {
            return customLoginUrl;
        }
        Instances__c instance = InstanceServices.getInstance(auth.Instance__c);
        return InstanceServices.getLoginEndpoint(instance);
    }

    private HttpRequest getUserInfoRequest(String accessToken, String loginEndpoint) {
        HttpRequest request = new HttpRequest();
        String endpoint = loginEndpoint + OAUTH_USERINFO_URL;
        request.setEndpoint(endpoint + accessToken);
        request.setMethod('GET');
        return request;
    }

    public class UserInfoResponse {
        @AuraEnabled
        public String preferred_username;
        @AuraEnabled
        public Boolean isAuthorized = false;

        public UserInfoResponse(Boolean isAuthorized) {
            this.isAuthorized = isAuthorized;
        }
    }

    public class TokenResponse {
        public String access_token;
        public String refresh_token;
        public Id org_id;
        public String id;
        public String instance_url;
        public Id user_id;
        public String error;
        public String error_description;

        public Id getUserId() {
            if(user_id == null) {
                if(String.isBlank(id)) {
                    return null;
                }

                Integer lastIndexOf = id.lastIndexOf('/');
                user_id = lastIndexOf != -1 ? id.substring(lastIndexOf+1) : null;
            }

            return user_id;
        }

        public Id getOrgId() {
            if(org_id == null) {
                if(String.isBlank(id)) {
                    return null;
                }

                List<String> ids = id.split('/');
                org_id = (ids.size()-2 > 0) ? ids[ids.size() - 2] : null;
            }

            return org_id;
        }
    }
}