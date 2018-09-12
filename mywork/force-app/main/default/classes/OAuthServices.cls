public with sharing class OAuthServices {

    public static String OAUTH_CACHE_GENERIC_INSERT_ERROR_MESSAGE = 'Unable to to insert cache status record.';
    public static String OAUTH_CACHE_INVALID_DATA_ERROR_MESSAGE = 'Invalid data passesd to oauth request cache.';

    /**
    * Creates a csrf token and stores it for the current user.
    * @throws DmlException
    */
    public static String generateCSRFToken() {
        String salt = String.valueOf(Crypto.getRandomInteger());
        String key = UserInfo.getUserId();

        Blob tokenBlob = Crypto.generateMac('HmacSHA256', Blob.valueOf(salt), Blob.valueOf(key));
        String csrfToken = EncodingUtil.base64Encode(tokenBlob);

        ALM_Private__c userData = ALM_Private__c.getInstance(UserInfo.getUserId());
        userData.CSRF_Token__c = csrfToken;
        upsert userData;

        return csrfToken;
    }

    /**
    * @throws DMLException, ALMException
    */
    public static Auth_User__c upsertAuthUser(OAuthRequest.TokenResponse tokenResponse, String instanceId, Boolean isForTools) {
        if (String.isEmpty(instanceId)) {
            throw new ALMException('Missing instance ID from state');
        }

        List<Auth_User__c> authUsers = new List<Auth_User__c>();

        if (isForTools) {
            Auth_User__c authUser = getAuthUserForTools(instanceId);
            if (authUser != null) {
                authUser.User__c = UserInfo.getUserId();
                authUsers.add(authUser);
            }
        } else {
            authUsers = [
                SELECT  Id
                FROM Auth_User__c
                WHERE Instance__c =: instanceId
                AND User__c =: UserInfo.getUserId()
                AND Instance_User__c =: tokenResponse.getUserId()
                AND Is_For_Tools__c = false
                ORDER BY LastModifiedDate DESC
                LIMIT 1
            ];
        }

        Auth_User__c authUser = null;
        if (!authUsers.isEmpty()) {
            authUser = authUsers[0];
        } else {
            authUser = new Auth_User__c();
            authUser.User__c = UserInfo.getUserId();
            authUser.Instance__c = instanceId;
        }

        return upsertAuthUser(tokenResponse, authUser, isForTools);
    }

    /**
    * @throws DMLException
    */
    public static Auth_User__c upsertAuthUser(OAuthRequest.TokenResponse tokenResponse, Auth_User__c authUser, Boolean isForTools) {

        updateAuthUserFromResponse(tokenResponse, authUser);
        authUser.Is_For_Tools__c = isForTools;
        return upsertAuthUserRecord(authUser);
    }

    public static Auth_User__c upsertAuthUserRecord(Auth_User__c authUser) {
        upsert authUser;
        return authUser;
    }

    /**
    * Updates the Auth_User__c from the token response. Only the reference is updated. No DML will be performed.
    */
    public static Auth_User__c updateAuthUserFromResponse(OAuthRequest.TokenResponse tokenResponse, Auth_User__c authUser) {

        authUser.Access_Token__c = tokenResponse.access_token;
        if (String.isNotBlank(tokenResponse.refresh_token)) {
            authUser.Refresh_Token__c = tokenResponse.refresh_token;
        }

        authUser.Is_Refresh_Token_Valid__c = String.isBlank(tokenResponse.error);
        authUser.Org_ID__c = tokenResponse.getOrgId();
        authUser.Instance_User__c = tokenResponse.getUserId();
        authUser.Instance_URL__c = tokenResponse.instance_url;
        return authUser;
    }

    /**
    *  @return Map instanceId => Auth_User__c
    */
    public static Map<Id,Auth_User__c> getAuthUsersForTools(Set<String> instanceIds) {
        Set<Id> convertedInstanceIds = new Set<Id>();
        for (String instanceId : instanceIds) {
            convertedInstanceIds.add((Id)instanceId);
        }

        return getAuthUsers(convertedInstanceIds, true, null);
    }

    public static Auth_User__c getAuthUserForTools(String instanceId) {
        Map<Id,Auth_User__c> results = getAuthUsersForTools(new Set<String>{instanceId});

        Auth_User__c auth;

        if (!results.isEmpty()) {
            auth = results.get(instanceId);
        }

        return auth;
    }

    public static Auth_User__c getAuthUser(Id instanceId, Boolean isForTools) {
        Map<Id, Auth_User__c> authUsers = getAuthUsers(new Set<Id>{instanceId}, isForTools, UserInfo.getUserId());

        return authUsers.isEmpty() ? null : authUsers.get(instanceId);
    }

    public static Auth_User__c getAuthUser(Id instanceId, Boolean isForTools, Id userId) {
        Map<Id, Auth_User__c> authUsers = getAuthUsers(new Set<Id>{instanceId}, isForTools, userId);

        return authUsers.isEmpty() ? null : authUsers.get(instanceId);
    }

    public static Map<Id, Auth_User__c> getAuthUsers(Set<Id> instanceIds, Boolean isForTools, Id userId) {
        String queryString =
            'SELECT ' +
                'Id, Org_ID__c, User__c, Refresh_Token__c, Instance__c, Instance_User__c, ' +
                'Instance_URL__c, Access_Token__c, Is_Refresh_Token_Valid__c, Is_For_Tools__c ' +
            'FROM Auth_User__c ' +
            'WHERE Instance__c IN :instanceIds ' +
            'AND Is_For_Tools__c = :isForTools ';

        if (userId != null) {
            queryString += 'AND User__c = :userId ';
        }

        queryString += 'ORDER BY LastModifiedDate ASC';

        Map<Id, Auth_User__c> instanceIdToAuthUser = new Map<Id, Auth_User__c>();
        for (Auth_User__c authUser : Database.query(queryString)) {
            instanceIdToAuthUser.put(authUser.Instance__c, authUser);
        }

        return instanceIdToAuthUser;
    }

    public static Auth_User__c getSightlineAuthUser() {
        Instances__c sightlineOrg = InstanceServices.almInstance;
        return (sightlineOrg != null ? getAuthUserForTools(sightlineOrg.Id) : null);
    }

    public static Map<String, Object> getStateMap(String stateParams) {
        Map<String, Object> stateMap;
        try {
            stateMap = (Map<String, Object>)JSON.deserializeUntyped(stateParams);
        } catch(Exception e) {
            stateMap = new Map<String, Object>();
        }

        return stateMap;
    }

    public static AppSettings getAppSettings() {
        ALM_Private__c settings = ALM_Private__c.getOrgDefaults();
        if (settings == null || String.isBlank(settings.Callback_URL__c)
             || String.isBlank(settings.Consumer_Key__c) || String.isBlank(settings.Consumer_Secret__c)) {
            throw new ALMException('All OAuth settings must be defined in ALM_Private__c setting.');
        }
        return new AppSettings(settings);
    }

    public class AppSettings {
        public String callBackURL;
        public String consumerKey;
        public String consumerSecret;

        public AppSettings(ALM_Private__c settings) {
            this.callBackURL = settings.Callback_URL__c;
            this.consumerKey = settings.Consumer_Key__c;
            this.consumerSecret = settings.Consumer_Secret__c;
        }

        public AppSettings(String callBackURL, String consumerKey, String consumerSecret) {
            this.callBackURL = callBackURL;
            this.consumerKey = consumerKey;
            this.consumerSecret = consumerSecret;
        }
    }

    /**
    * @throws ALMException
    */
    public static void putOAuthRequestStatusInCache(String instanceId, String userId, Boolean isInProgress) {

        if (String.isBlank(instanceId) || String.isBlank(userId)) {
            String errorMessage = OAUTH_CACHE_INVALID_DATA_ERROR_MESSAGE + ': ' +
                                  (String.isBlank(instanceId) ? 'blank instance Id' : '') +
                                  (String.isBlank(userId) ? ', blank user Id' : '');
            throw new ALMException(errorMessage);
        }

        try {
            OAuthRequestState cachedState = new OAuthServices.OAuthRequestState(instanceId, userId, isInProgress);
            State.store(cachedState);
        } catch (State.StateException e) {
            throw new ALMException(OAUTH_CACHE_GENERIC_INSERT_ERROR_MESSAGE);
        }
    }

    public static Boolean OAuthRequestIsInProgress(String instanceId, String userId) {
        OAuthRequestState cachedState = new OAuthServices.OAuthRequestState(instanceId, userId);
        try {
            State.retrieve(cachedState);
            return cachedState.getIsInProgress();
        } catch (State.StateException e) {
            return false;
        }
    }

    public static List<PageMessage> checkSightlineAuthUser () {
        List<PageMessage> messagesToReturn = new List<PageMessage>();
        if(OAuthServices.getAuthUserForTools(InstanceServices.almInstance.Id).Org_Id__c != UserInfo.getOrganizationId()) {
            messagesToReturn.add(new PageMessage(
                ApexPages.Severity.WARNING,
                System.Label.Admin_Console_OAuth_Wrong_Org
            ));
        }
        return messagesToReturn;
    }

    public class OAuthRequestState implements State.IStateful {

        private String instanceId;
        private String userId;
        private Boolean isInProgress;

        public OAuthRequestState(String instanceId, String userId) {
            this(instanceId, userId, false);
        }

        public OAuthRequestState(String instanceId, String userId, Boolean isInProgress) {
            this.instanceId = instanceId;
            this.userId = userId;
            this.isInProgress = isInProgress;
        }

        public String getStateToken() {
            return (this.instanceId + '|' + this.userId);
        }

        public String serialize() {
            return JSON.serialize(this);
        }

        public void deserialize(String state) {
            OAuthRequestState requestState = (OAuthRequestState) JSON.deserialize(state, OAuthRequestState.class);
            this.instanceId = requestState.instanceId;
            this.userId = requestState.userId;
            this.isInProgress = requestState.isInProgress;
        }

        public Boolean getIsInProgress() {
            return this.isInProgress;
        }
    }
}
