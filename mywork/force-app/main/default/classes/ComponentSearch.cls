public with sharing class ComponentSearch {

    public static String LAST_MODIFIED_DATE = 'Overall_Last_Modified_Date__c';
    public static String SORT_ORDER_DESC = 'desc';
    public static String INSTANCES_SEPARATOR = ',';
    public static Integer DEFAULT_PAGE_SIZE = 500;

    public Integer maxResultSize { get; set; }
    public Integer requestedPageNumber { get; set; }

    public String cType {get; set;}
    public String name {get; set;}
    public String parentName {get; set;}
    public List<Id> componentIds;
    public String selectedInstances {get; set;}
    public Set<String> selectedUsers {get; set;}
    public List<Id> excludedComponentIds;
    public Boolean includeProfiles;
    private Set<String> existingComponentKeys;


    public ComponentSearch(Set<String> existingComponentKeys) {
        this.existingComponentKeys = existingComponentKeys;
        sortField = LAST_MODIFIED_DATE;
        sortDirection = SORT_ORDER_DESC;
        name = '';
        cType = '';
        parentName = '';
        maxResultSize = 10;
        requestedPageNumber = 0;
        includeProfiles = true;
    }

    /**
    * @param selectedComps  a comma delimited string of component keys
    * @param name  component name to filter by
    * @param type  component type to filter by
    * @param parentComponent  parent component type to filter by
    * @param instances  comma delimited string of instances to filter by
    * @param deleted  boolean for including deleted components in search results
    * @param modifiedByUsernames    users to filter by
    */
    public ComponentSearch(String selectedComps, String name, String type, String parentComponent,
         String instances, List<String> modifiedByUsernames) {

        this(
            String.isBlank(selectedComps) ? new Set<String>() : new Set<String>(selectedComps.split(','))
        );

        if (String.isNotBlank(name)) {
            this.name = name;
        }
        if (String.isNotBlank(type)) {
            this.cType = type;
        }
        if (String.isNotBlank(parentComponent)) {
            this.parentName = parentComponent;
        }
        if (String.isNotBlank(instances)) {
            this.selectedInstances = instances;
        }

        if (modifiedByUsernames != null) {
            this.selectedUsers = new Set<String>(modifiedByUsernames);
        }
    }

    private List<ComponentSearchWrapper> searchResults;
    public List<ComponentSearchWrapper> currentPage {
        get {
            if( searchResults == null ) {
                return new List<ComponentSearchWrapper>();
            }
            if (sortField == LAST_MODIFIED_DATE) {
                ComponentSearchWrapper.sortDescending = (sortDirection == SORT_ORDER_DESC);
                searchResults.sort();
            }
            return searchResults;
        }
        private set;
    }

    public String sortDirection { get; set; }

    public String sortField { get; set; }

    public void setExistingComponentKeys( Set<String> existingComponentKeys ) {
        this.existingComponentKeys = existingComponentKeys;
    }

    public void toggleSort() {
        sortDirection = sortDirection.equals('asc') ? SORT_ORDER_DESC : 'asc';

        doSearch();
    }

    public void doQuery() {
        String componentSoql = 'Select Id, Name, Full_Name__c, Type__c, Deleted__c, Parent_Component__r.Full_Name__c, Parent_Component__r.Name, Field_Modified_Data__c, Overall_Last_Modified_Date__c';
        componentSoql       += ' From Component__c';
        doQuery( componentSoql, ' Where Deleted__c = false AND Type__c != \'Apex Unit Test\'');
    }

    private Boolean isPaginatedQuery() {
      return this.requestedPageNumber > 0;
    }

    private void doQuery(String queryString, String whereClause) {
       try {
            Set<String> instances = getInstancesSet();

            String query = queryString + whereClause + ' ORDER BY ' + sortField + ' ' + sortDirection + ' NULLS LAST, Id DESC LIMIT ' + maxResultSize;

            if (this.isPaginatedQuery()) {
                query += ' OFFSET ' + String.valueOf((this.requestedPageNumber - 1) * this.maxResultSize);
            }

            searchResults = new List<ComponentSearchWrapper>();

            Boolean hasUserFilter = selectedUsers != null && !selectedUsers.isEmpty();


            for (Component__c component : (List<Component__c>)Database.query( query )) {
                if (!this.isPaginatedQuery() && searchResults.size() >= maxResultSize) {
                   break;
                }

                if (component.Field_Modified_Data__c != null) {
                    List<FieldModifiedData> fieldModifiedData = (List<FieldModifiedData>) JSON.deserialize(component.Field_Modified_Data__c, List<FieldModifiedData>.class);

                    //filter matching components
                    for (FieldModifiedData o : fieldModifiedData) {
                        if ((instances.isEmpty() || instances.contains(o.environmentName.toLowerCase()))
                            && (!hasUserFilter || selectedUsers.contains(o.lastModifiedByName))) {
                            addSearchResultItem( existingComponentKeys, component, o.environmentName, o.lastModifiedDate, o.lastModifiedByName, o.deleted );
                        }

                        if (!this.isPaginatedQuery() && searchResults.size() >= maxResultSize) {
                            break;
                        }
                    }
                } else {
                    // If component doesn't have JSON data, we still need to create a wrapper for the component
                    String environmentName = '';
                    Datetime lastModifiedDate = null;
                    String lastModifiedBy = '';
                    addSearchResultItem( existingComponentKeys, component, environmentName, lastModifiedDate, lastModifiedBy, false );
                }
            }

       } catch (Exception e) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'Could not query for components.  The error was: ' + e.getMessage()));
       }
    }

    public PageReference doSearch() {
        return doSearch(false);
    }

    public PageReference doSearch(Boolean addingSelectedComponents) {

        String componentSOQL = 'SELECT Id, Name, Full_Name__c, Type__c, Deleted__c, Parent_Component__r.Name, Parent_Component__r.Full_Name__c, Field_Modified_Data__c From Component__c ';
        String whereClause = '';

        if (String.isNotEmpty(selectedInstances)) {
            whereClause += (whereClause == '') ? ' WHERE ' : ' AND ';
            whereClause += ' Source_Instances__c INCLUDES (';
            List<String> instances = new List<String>();
            for (String instance : selectedInstances.split(INSTANCES_SEPARATOR) ) {
               instances.add( '\'' + String.escapeSingleQuotes(instance) + '\'' );
            }
            whereClause += String.join(instances, ',');
            whereClause += ')';
        }

        if (selectedUsers != null && !selectedUsers.isEmpty()) {
            whereClause += (whereClause == '') ? ' WHERE ' : ' AND ';
            whereClause += ' Last_Modified_Users__c INCLUDES (';

            List<String> sanitizedUsers = new List<String>();
            for (String user : selectedUsers) {
                sanitizedUsers.add( '\'' + String.escapeSingleQuotes(user) + '\'');
            }

            whereClause += String.join(sanitizedUsers, ',');
            whereClause += ')';
        }

        if (componentIds != null && !componentIds.isEmpty()) {
            whereClause += (whereClause == '' ? ' WHERE ' : ' AND ');
            whereClause += ' Id IN (';

            List<String> queryIdList = new List<String>();
            for(Id compId : this.componentIds) {
                queryIdList.add('\'' + String.escapeSingleQuotes(compId) + '\'');
            }

            whereClause += String.join(queryIdList, ',');
            whereClause += ')';
        }

        if (excludedComponentIds != null && !excludedComponentIds.isEmpty()) {
            whereClause += (whereClause == '' ? ' WHERE ' : ' AND ');
            whereClause += ' Id NOT IN (';

            List<String> queryIdList = new List<String>();
            for(Id compId : this.excludedComponentIds) {
                queryIdList.add('\'' + String.escapeSingleQuotes(compId) + '\'');
            }

            whereClause += String.join(queryIdList, ',');
            whereClause += ')';
        }

        if (!String.IsBlank(name)) {
            whereClause += (whereClause == '' ? ' WHERE ' : ' AND ');
            whereClause += '(Name LIKE \'%'+String.escapeSingleQuotes(name)+'%\' OR Full_Name__c LIKE \'%'+String.escapeSingleQuotes(name)+'%\')';
        }

        if (!String.IsBlank(cType)) {
            whereClause += (whereClause == '' ? ' WHERE ' : ' AND ');
            whereClause += 'Type__c LIKE \'%'+String.escapeSingleQuotes(cType)+'%\'';
        }

        if (!String.IsBlank(parentName)) {
            whereClause += (whereClause == '' ? ' WHERE ' : ' AND ');
            whereClause += 'Parent_Component__r.Name LIKE \'%'+String.escapeSingleQuotes(parentName)+'%\'';
        }

        whereClause += (whereClause == '' ? ' WHERE ' : ' AND ');
        whereClause += 'Type__c != \'Apex Unit Test\'';

        if (!includeProfiles) {
            whereClause += ' AND Type__c != \'' + ComponentDocServices.PROFILE_COMPONENT_TYPE + '\'';
        }

        doQuery( componentSOQL, whereClause );

        return null;
    }

    /**
    *   Gets the ComponentSearchWrappers from selected components
    *   @param  selectedComponentIdString  comma delimited list of component Id tokens (see
    *                   ComponentSearchWrapper#getKey) where keys are of the form instanceName|componentId
    *   @return List<ComponentSearchWrapper>
    *   @throws ALMException
    */
    public static List<ComponentSearchWrapper> getSelectedComponents(String selectedComponentIdString) {
        List<String> selectedCompKeys = selectedComponentIdString.split(',');
        List<ComponentSearchWrapper> selectedComponents = new List<ComponentSearchWrapper>();

        if(selectedCompKeys.isEmpty()) {
            return selectedComponents;
        }

        Set<Id> componentIds = new Set<Id>();
        Set<String> instanceList = new Set<String>();
        for(String key : selectedCompKeys) {
            List<String> keyParts = key.split('\\|');
            if(keyParts.size() != 2) {
                throw new ALMException(System.Label.Generic_Error + ': Invalid Component Key found: ' + key);
            }
            instanceList.add((String)keyParts[0]);
            componentIds.add((Id)keyParts[1]);
        }

        ComponentSearch compSearchTemp = new ComponentSearch(new Set<String>());

        List<Id> uniqueCompIds = new List<Id>();
        uniqueCompIds.addAll(componentIds);
        compSearchTemp.componentIds = uniqueCompIds;
        compSearchTemp.selectedInstances = String.join(new List<String>(instanceList), INSTANCES_SEPARATOR);
        compSearchTemp.maxResultSize = DEFAULT_PAGE_SIZE;

        compSearchTemp.doSearch(true);

        // Map of Key -> component wrapper
        Map<String, ComponentSearchWrapper> searchWrapperMap = new Map<String, ComponentSearchWrapper>();
        for(ComponentSearchWrapper wrapper : compSearchTemp.currentPage) {
            searchWrapperMap.put(wrapper.getKey(), wrapper);
        }

        for(String key : selectedCompKeys) {
            ComponentSearchWrapper matchingComponent = searchWrapperMap.get(key);

            // Since our query can pull back multiple component
            // instances, check to see if this specific wrapper is used
            if(matchingComponent != null) {
                selectedComponents.add(matchingComponent);
            }
        }

        return selectedComponents;
    }

    private void addSearchResultItem(Set<String> existingComponentKeys, Component__c component, String environmentName, Datetime lastModifiedDate, String lastModifiedBy, Boolean isDeleted) {
        if (String.isEmpty(environmentName)) {
            return;
        }

        ComponentSearchWrapper componentSearchItem = ComponentSearchWrapper.addWrapper(searchResults, component, environmentName, '', lastModifiedDate, lastModifiedBy, isDeleted);
        componentSearchItem.existsOnCurrentBacklog = existingComponentKeys.contains( componentSearchItem.getKey() );
    }

    private Set<String> getInstancesSet() {
        Set<String> instances = new Set<String>();

        if (!String.isEmpty(selectedInstances)) {
            for(String instance : selectedInstances.split(INSTANCES_SEPARATOR, 0)) {
                instances.add( instance.toLowerCase() );
            }
        }

        return instances;
    }

}
