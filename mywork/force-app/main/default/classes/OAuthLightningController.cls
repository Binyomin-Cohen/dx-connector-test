public with sharing class OAuthLightningController extends OAuthController {

    public static String OAUTH_ERROR_MESSAGE = 'An error occurred during the authentication process';

    public OAuthLightningController() {
        this.isForTools = false;
    }

    public void setIsForTools(Boolean isForTools) {
        this.isForTools = isForTools;
    }

    /**
    * Instance id used for going through OAuth flow
    */
    @AuraEnabled
    public static String auraAuthorizeInstance(String instanceId, Boolean isForTools) {
        String userId = UserInfo.getUserId();
        Boolean inProgress = true;
        try {
            OAuthServices.putOAuthRequestStatusInCache(instanceId, userId, inProgress);
        } catch (ALMException e) {
            ALMLogServices.error(e, ALMLogServices.Application.OAUTH);
            throw new AuraHandledException(OAUTH_ERROR_MESSAGE);
        }

        OAuthLightningController oauth = new OAuthLightningController();
        oauth.setIsForTools(isForTools);
        oauth.selectedInstanceId = instanceId;
        Boolean showPopup = true;

        PageReference redirectPageReference = isForTools ? Page.OAuthRedirectHandlerTools : Page.OAuthRedirectHandler;

        String customRedirectHandlerUrl = URL.getSalesforceBaseUrl().toExternalForm() + redirectPageReference.getUrl();

        return oauth.getAuthorizeInstanceUrl(showPopup, customRedirectHandlerUrl);
     }

    /**
    * Instance id used for going through OAuth flow
    */
    @AuraEnabled
    public static OAuthRequest.UserInfoResponse auraGetAuthStatus(String instanceId, Boolean isForTools) {
        Auth_User__c auth = OAuthServices.getAuthUser(instanceId, isForTools);

        OAuthRequest request = new OAuthRequest();
        try {
            return request.getUserInfo(auth);
        } catch (ALMException ae) {
            throw new AuraHandledException(ae.getMessage());
        }
    }

    @AuraEnabled
    public static Boolean getOAuthInProgressStatusFromCache(String instanceId) {
         String userId = UserInfo.getUserId();
         return OAuthServices.OAuthRequestIsInProgress(instanceId, userId);
    }
}
