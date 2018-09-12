public virtual with sharing class OAuthRedirectController extends OAuthController {
    private Id instanceIdFromState;

    public OAuthRedirectController() {
        this.isForTools = false;
    }
    public void handleRedirect(){
        handleOAuthRedirect();
        try{
            OAuthServices.putOAuthRequestStatusInCache(instanceIdFromState, userInfo.getUserId(), false);
        }catch(DMLException dex){
            ApexPages.addMessage(new ApexPages.Message(
                    ApexPages.Severity.ERROR,
                    System.Label.Generic_Error + ': could not update cache for instance ' + instanceIdFromState
                ));
        }
    }
    public override void loadState(Map<String, Object> stateMap) {
        if (stateMap.containsKey(INSTANCE_STATE_PARAM)) {
            instanceIdFromState = (String)stateMap.get(INSTANCE_STATE_PARAM);
        }
    }
}