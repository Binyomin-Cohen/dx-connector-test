public with sharing class PageState implements State.IStateful {
    public static final String DEFAULT_APPLICATION_TOKEN = 'PageState';

    public Map<String, Object> stateMap;
    
    private String applicationToken;

    /**
    * Constructs a PageState model with the given application token.
    * @param applicationToken - The application token that identifies the state.
    */
    public PageState(String applicationToken) {
        this.applicationToken = applicationToken;
    }

    /**
    * Constructs a PageState model with the default application token.
    */
    public PageState() {
        this(DEFAULT_APPLICATION_TOKEN);
    }

    /**
    * Constructs a PageState model with the default application token and the given state map.
    * @param stateMap - The map that represents the page state.
    */
    public PageState(Map<String, Object> stateMap) {
        this();
        this.stateMap = stateMap;
    }

    /**
    * Constructs a PageState model with the given application token and the given state map.
    * @param applicationToken - The application token that identifies the state.
    * @param stateMap - The map that represents the page state.
    */
    public PageState(String applicationToken, Map<String, Object> stateMap) {
        this(applicationToken);
        this.stateMap = stateMap;
    }

    /**
    * Retrieves the state token used to identify the page state record.
    * @return - The state token.
    */
    public String getStateToken() {
        return this.applicationToken + State.STATE_TOKEN_DELIM + UserInfo.getUserId();
    }

    /**
    * Serializes the page state.
    * @return - The serialized representation of the page state.
    */
    public String serialize() {
        return JSON.serialize(this.stateMap);
    }

    /**
    * Deserializes the page state.
    * @param state - The serialized representation of the page state.
    */
    public void deserialize(String state) {
        stateMap = (Map<String, Object>)JSON.deserializeUntyped(state);
    }

    /**
    * Expires the page state so that it cannot be used in the future.
    * @throws ALMException
    */
    public void expire() {
        List<State__c> state = [SELECT Id FROM State__c WHERE Token__c = :getStateToken()];
        if (!state.isEmpty()) {
            try {
                delete state;
            } catch (Exception e) {
                throw new ALMException(e.getMessage());
            }
        }
    }
}