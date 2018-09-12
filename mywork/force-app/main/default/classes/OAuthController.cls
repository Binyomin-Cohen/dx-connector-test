public virtual with sharing class OAuthController {
    public String selectedInstanceId {get; set;}
    protected Boolean isForTools;
    public static final String INSTANCE_STATE_PARAM = 'instance_id';
    public static final String CSRF_STATE_PARAM = 'csrf';

    private static final String PAGE_STATE_TOKEN = 'PageState OAuth';

    protected Map<String, Object> initialPageStateMap {get; set;}

    public OAuthController() {
        this.isForTools = true;
    }

    public PageReference authorizeInstance() {
        String authorizeInstanceUrl = getAuthorizeInstanceUrl();
        PageReference oAuthPage = new PageReference(authorizeInstanceUrl);
        oAuthPage.setRedirect(true);
        return oAuthPage;
    }

    public String getAuthorizeInstanceUrl() {
        Boolean showPopup = false;
        String standardRedirectHandlerUrl = URL.getCurrentRequestUrl().toExternalForm();
        return getAuthorizeInstanceUrl(showPopup, standardRedirectHandlerUrl);
    }

    public String getAuthorizeInstanceUrl(Boolean showPopup, String redirectHandlerUrl) {
        String currentUrl = redirectHandlerUrl;

        Instances__c selectedInstance = InstanceServices.getInstance( getInstanceIdToAuthorize() );

        String loginEndpoint = InstanceServices.getLoginEndpoint(selectedInstance);

        String csrfToken;
        try {
             csrfToken = OAuthServices.generateCSRFToken();
        } catch(Exception ex) {
            ApexPages.addMessages(ex);
            return null;
        }

        OAuthRequest request = new OAuthRequest();
        Map<String,String> state = getState();

        state.put(CSRF_STATE_PARAM, csrfToken);

        request.setState(currentUrl, state);

        return request.getAuthorizationUrl(loginEndpoint, showPopup);
    }

    public void handleOAuthRedirect() {
        Map<String, String> params = ApexPages.currentPage().getParameters();
        if (params.containsKey('code')) {
            String code = params.get('code');
            Map<String, Object> stateMap = OAuthServices.getStateMap(params.get('state'));

            String csrfToken = (String)stateMap.get(CSRF_STATE_PARAM);
            ALM_Private__c userData = ALM_Private__c.getInstance(UserInfo.getUserId());

            if (csrfToken == null || userData == null || userData.CSRF_Token__c != csrfToken) {
                ApexPages.addMessage(new ApexPages.Message(
                    ApexPages.Severity.ERROR,
                    System.Label.Generic_Error + ': invalid CSRF token'
                ));
                return;
            }

            String instanceId = (String)stateMap.get(INSTANCE_STATE_PARAM);
            Instances__c instance = InstanceServices.getInstance(instanceId);

            if (instance == null) {
                 ApexPages.addMessage(new ApexPages.Message(
                    ApexPages.Severity.ERROR,
                    System.Label.Generic_Error + ': instance with id ' + instanceId + ' does not exist'
                ));
                return;
            }

            String loginEndpoint = InstanceServices.getLoginEndpoint(instance);

            OAuthRequest request = new OAuthRequest();

            try {
                OAuthRequest.TokenResponse tokenResponse = request.getAccessToken(loginEndpoint + OAuthRequest.OAUTH_TOKEN_URL, OAuthRequest.AUTH_GRANT_TYPE_CODE, code);

                if (String.isBlank(tokenResponse.error)) {
                    OAuthServices.upsertAuthUser(tokenResponse, instanceId, isForTools);
                } else {
                    //TODO: what to do with errors here?
                    ApexPages.addMessage(new ApexPages.Message(
                        ApexPages.Severity.ERROR,
                        tokenResponse.error + ':' + tokenResponse.error_description
                    ));
                }
            } catch(Exception e) {
                ApexPages.addMessage(new ApexPages.Message(
                    ApexPages.Severity.ERROR,
                    System.Label.Generic_Error + ': ' + e.getMessage()
                ));
            }

            loadState(stateMap);
        }
    }

    /**
    * Load the state of the application after returning from the oauth flow
    */
    public virtual void loadState(Map<String, Object> stateMap) {

    }

    /**
    * Gets the state of the application before going through the oauth flow
    */
    public virtual Map<String, String> getState() {
        return new Map<String, String> {
            INSTANCE_STATE_PARAM => getInstanceIdToAuthorize()
        };
    }

    /**
    * Instance id used for going through OAuth flow
    */
    public virtual String getInstanceIdToAuthorize() {
        return selectedInstanceId;
    }

    @RemoteAction
    public static OAuthRequest.UserInfoResponse getAuthStatus(String instanceId) {
        Auth_User__c auth = OAuthServices.getAuthUserForTools(instanceId);

        OAuthRequest request = new OAuthRequest();
        return request.getUserInfo(auth);
    }

    @RemoteAction
    public static String remoteAuthorizeInstanceForTools(String instanceId) {
        Boolean isForTools = true;
        return OAuthLightningController.auraAuthorizeInstance(instanceId, isForTools);
    }

    @RemoteAction
    public static Boolean getOAuthInProgressStatusFromCache(String instanceId) {
        return OAuthServices.OAuthRequestIsInProgress(instanceId, UserInfo.getUserId());
    }

    public void savePageState() {
        Map<String, Object> pageStateMap = getCurrentPageStateDifferenceMap();

        if (!pageStateMap.isEmpty()) {
            try {
                State.store(new PageState(getPageStateToken(), pageStateMap));
            } catch (State.StateException se) {
            } catch (Exception e) {
                throw new ALMException(e.getMessage());
            }
        } else {
            expirePageState();
        }
    }

    public Map<String, Object> loadPageState() {
        PageState stateInstance = new PageState(getPageStateToken());

        try {
            State.retrieve(stateInstance);
        } catch (State.StateException se) {
        } catch (Exception e) {
            throw new ALMException(e.getMessage());
        }

        return stateInstance.stateMap;
    }

    public void expirePageState() {
        new PageState(getPageStateToken()).expire();
    }

    protected virtual Map<String, Object> getCurrentPageStateMap() {
        return new Map<String, Object>();
    }

    protected virtual String getPageStateToken() {
        return PAGE_STATE_TOKEN;
    }

    private Map<String, Object> getCurrentPageStateDifferenceMap() {
        Map<String, Object> currentPageStateDifferenceMap = getCurrentPageStateMap();

        if (initialPageStateMap != null) {
            for (String key : currentPageStateDifferenceMap.keySet()) {
                if (initialPageStateMap.containsKey(key) && (initialPageStateMap.get(key) == currentPageStateDifferenceMap.get(key))) {
                    currentPageStateDifferenceMap.remove(key);
                }
            }
        }

        return currentPageStateDifferenceMap;
    }
}