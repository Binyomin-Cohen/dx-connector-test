public with sharing class ClientComponentSearchController {

    public static Integer defaultPageSize { get { return 10; } set; }

    private static Integer MAX_PAGE_SIZE = 200;

    public String userTimeZone {
        get {
            return UserInfo.getTimeZone().getId();
        }
    }

    public String userLocale {
        get {
            return UserInfo.getLocale();
        }
    }

    public Integer userRequestedPageSize {
        get {
            if (userRequestedPageSize == null) {
                User_Preferences__c preference = User_Preferences__c.getValues(UserInfo.getUserId());
                if (preference == null) {
                    userRequestedPageSize = defaultPageSize;
                } else {
                    Decimal pageSize = preference.Comp_Search_Page_Size__c;
                    userRequestedPageSize = pageSize == null ? defaultPageSize : pageSize.intValue();
                }
            }

            return userRequestedPageSize;
        }

        set;
    }

    @RemoteAction
    public static void updateUserPreferences(Integer requestedPageSize) {
        User_Preferences__c preference = User_Preferences__c.getInstance(UserInfo.getUserId());
        preference.Comp_Search_Page_Size__c = requestedPageSize;

        try {
            upsert preference;
        } catch (DMLException e) {
            throw new ALMException('An error occured updating the User_Preferences__c custom setting: '+ e.getMessage() );
        }
    }

    @RemoteAction
    public static ComponentSearchResult getSearchResults(String name,
                                                         String type,
                                                         String parentComponent,
                                                         String instances,
                                                         String selectedComps,
                                                         List<String> modifiedByUsernames)
    {

        ComponentSearch compSearch = new ComponentSearch(selectedComps, name, type, parentComponent,
             instances, modifiedByUsernames);
        compSearch.includeProfiles = false;

        return searchComponents(compSearch, MAX_PAGE_SIZE + 1, 0);
    }

    @AuraEnabled
    public static ComponentSearchResult doPageSearch(String searchParamsJSON) {

        SearchParameters searchParams;
        try {
            searchParams =
             (SearchParameters) JSON.deserialize(searchParamsJSON, SearchParameters.class);
        } catch(JSONException je) {
            throw new AuraHandledException( System.Label.Generic_Error + ' \n'+ je.getMessage() );
        }

        ComponentSearchResult results;
        // First check if cached results should be used
        if ( !searchParams.isFilteredSearch() && searchParams.currentPage == 1 ) {
            List<Id> cachedComponentIds = ComponentDocServices.getCachedRecentlyModifiedComponents();
            if (cachedComponentIds.size() > 0) {
                List<Component__c> comps = ComponentDocServices.queryComponentsByIds(cachedComponentIds);
                results = new ComponentSearchResult(ComponentDocServices.makeComponentSearchWrappers(comps), true);
            } else if (cachedComponentIds.size() == 0) {
                ComponentDocServices.refreshRecentlyModifiedComponentsCache();
            }
        }

        // If not using cached results, perform a normal search
        if (results == null) {
            ComponentSearch compSearch = new ComponentSearch(searchParams.selectedComponents, searchParams.name,
                                                             searchParams.type, searchParams.parentComponent,
                                                             searchParams.instances, searchParams.selectedUsers);
            results = searchComponents(compSearch, searchParams.pageSize, searchParams.currentPage);
        }
        return results;
    }

    @AuraEnabled
    public static void createSelectedComponents(String selectedComponentIdString, String backlogItemId, String notes) {
        try {
            ComponentDocServices.createBacklogComponents(selectedComponentIdString, backlogItemId, notes);
        } catch(Exception ex) {
            ALMLogServices.error(ex, ALMLogServices.Application.COMPONENT_DOCUMENTATION);
            throw new AuraHandledException(ALMErrorServices.getValidationRuleMessage(ex.getMessage()));
        }
    }

    @AuraEnabled
    public static Integer getUserRequestedPageSize() {
        ClientComponentSearchController controller = new ClientComponentSearchController();
        return controller.userRequestedPageSize;
    }

    @AuraEnabled
    public static String getExistingComponentKeys(String backlogItemId) {
        List<String> existingKeysList = new List<String>();
        for(Backlog_Component__c bc : [SELECT Component__c, Source_Instance__r.Name, Source_Sandbox__c
                                       FROM Backlog_Component__c
                                       WHERE Backlog__c = :backlogItemId]) {
            String instanceName = (bc.Source_Instance__r.Name == null) ? bc.Source_Sandbox__c
                                                                       : bc.Source_Instance__r.Name;
            existingKeysList.add(instanceName + '|' + bc.Component__c);
        }
        return String.join(existingKeysList, ',');
    }

    @AuraEnabled
    public static void updatePageSizePreference(Integer pageSize) {
        updateUserPreferences(pageSize);
    }

    /**
    * Searches components and builds a ComponentSearchResult
    */
    private static ComponentSearchResult searchComponents(ComponentSearch compSearch, Integer maxResultSize, Integer pageNumber) {

        compSearch.maxResultSize = maxResultSize;
        compSearch.requestedPageNumber = pageNumber;
        compSearch.doSearch();

        ComponentSearchResult searchResults = new ComponentSearchResult();
        searchResults.results = compSearch.currentPage;
        //TODO: hasMore needs to be cleaned up to work with new pagination model
        searchResults.hasMore = (searchResults.results.size() > MAX_PAGE_SIZE);

        if (searchResults.hasMore) {
            // Remove last item to make it even with max page size
            searchResults.results.remove(MAX_PAGE_SIZE);
        }

        for (ComponentSearchWrapper wrapper : searchResults.results) {
            wrapper.checked = wrapper.existsOnCurrentBacklog;
        }

        return searchResults;
    }

    @testVisible
    public class ComponentSearchResult {
        @AuraEnabled
        public List<ComponentSearchWrapper> results;
        // TRUE if there are more results than what were returned
        @AuraEnabled
        public Boolean hasMore;

        public ComponentSearchResult() {
            this.hasMore = false;
        }

        public ComponentSearchResult(List<ComponentSearchWrapper> results, Boolean hasMore) {
            this.hasMore = hasMore;
            this.results = results;
        }
    }

    public class SearchParameters {
        @AuraEnabled
        public String name;
        @AuraEnabled
        public String type;
        @AuraEnabled
        public String parentComponent;
        @AuraEnabled
        public String instances;
        @AuraEnabled
        public List<String> selectedUsers;
        @AuraEnabled
        public String selectedComponents;
        @AuraEnabled
        public Integer currentPage;
        @AuraEnabled
        public Integer pageSize;

        public Boolean isFilteredSearch() {
            return String.isNotEmpty(name) || String.isNotEmpty(type) || String.isNotEmpty(parentComponent)
                                           || (selectedUsers != null) || String.isNotEmpty(instances);
        }
    }
}
