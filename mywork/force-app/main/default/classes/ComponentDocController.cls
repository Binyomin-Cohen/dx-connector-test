public with sharing class ComponentDocController {

    public static final String PROFILE_COMPONENT_TYPE = 'Profile';
    public static final String SUPPORTED_METADATA_TYPES_KEY = 'supportedMetadataTypes';
    public static final String INSTANCES_RUN_TIMES_KEY = 'instanceRunTimes';
    public static final String AVAILABLE_USERS_KEY = 'availableUsers';
    public static final String INSTANCES_KEY = 'instances';
    public static final String MORE_FILTERING_REQUIRED_MSG = Label.More_Filtering_Required;

    public String backlogItemId {get; set;}
    public String backlogItemName {get; set;}
    public String namespace {get; set;}

    public ComponentDocController(ApexPages.StandardSetController controller) {
        setPageContext();
    }

    @TestVisible
    private Boolean setPageContext() {
        String backlogId = ApexPages.currentPage().getParameters().get('id');
        Backlog__c backLogFromPageParams = BacklogItemServices.getBacklogRecord( backlogId );
        if( backLogFromPageParams == null )
            return false;
        backlogItemId = backLogFromPageParams.Id;
        backlogItemName = backLogFromPageParams.Name;
        namespace = SObjectServices.CURRENT_NAMESPACE;

        return PermissionServices.checkPagePermissions(new ComponentDocPermissions()) == PermissionServices.PermissionLevel.FULL;
    }

    @AuraEnabled
    public static Map<String, Object> getFormData(){
        Map<String, Object> formDataToReturn = new Map<String, Object>();

        formDataToReturn.put( SUPPORTED_METADATA_TYPES_KEY, SupportedMetadataTypes.getAll() );

        Map<String, String> instancesToRunTime = ComponentDocServices.getRunTimes();

        formDataToReturn.put( INSTANCES_RUN_TIMES_KEY, instancesToRunTime );

        List<String> sortedInstanceKeys = new List<String> (Pluck.Strings(Instances__c.Name, InstanceServices.getAllInstances()));
        sortedInstanceKeys.sort();

        formDataToReturn.put( INSTANCES_KEY, sortedInstanceKeys );
        formDataToReturn.put( AVAILABLE_USERS_KEY, ComponentDocServices.getAvailableUsers() );

        return formDataToReturn;
    }

    /**
    * Retrieve the documented backlog components for a given backlog item.
    * @param backlogItemId      the backlog item to look for documented components on
    * @param offset             query offset for the documented backlog components
    * @param pageSize           total backlog components to retrieve
    * @param getTotalComponentCount     whether to return total number of documented components
    * @return DocumentedComponentsQueryResult
    */
    @AuraEnabled
    public static DocumentedComponentsQueryResult queryDocumentedComponents(Id backlogItemId, Integer offset,
                                                                            Integer pageSize,
                                                                            Boolean getTotalComponentCount) {
        offset = Integer.valueof(offset);
        pageSize = Integer.valueof(pageSize);

        DocumentedComponentsQueryResult queryResult = new DocumentedComponentsQueryResult();
        if (getTotalComponentCount) {
            queryResult.totalDocumentedComponents = [
                SELECT count() FROM Backlog_Component__c
                 WHERE Backlog_Component__c.Backlog__c = :backlogItemId 
                 AND Component__r.Type__c != :PROFILE_COMPONENT_TYPE
            ];
        }
        queryResult.results = queryExistingMembersPaginated(backlogItemId, offset, pageSize);
        queryResult.hasMore = (queryResult.results.size() >= pageSize);
        return queryResult;
    }

    /**
    * Find any backlog component records that have changed from the given list of backlog component ids
    * @param backlogItemId      the backlog item to look for documented components on
    * @param knownBacklogComponentIds  the known Backlog_Component__c ids
    * @return DocumentedComponentDiff
    */
    @AuraEnabled
    public static DocumentedComponentDiff getBacklogComponentsDiffs(String backlogItemId,
        List<String> knownBacklogComponentIds) {

        if (knownBacklogComponentIds == null) {
            knownBacklogComponentIds = new List<String>();
        }

        Map<Id, Backlog_Component__c> documentedComponents = new Map<Id, Backlog_Component__c> (
            ComponentDocServices.getDocumentedComponents(backlogItemId)
        );

        List<String> deletedComponents = new List<String>();
        List<ComponentSearchWrapper> addedComponents = new List<ComponentSearchWrapper>();

        for (String backlogComponentId : knownBacklogComponentIds) {
            if (documentedComponents.containsKey(backlogComponentId)) {
                documentedComponents.remove(backlogComponentId);
            } else {
                deletedComponents.add(backlogComponentId);
            }
        }

        for (Backlog_Component__c backlogComponent : documentedComponents.values()) {
            addDocumentedComponent(addedComponents, backlogComponent);
        }

        return new DocumentedComponentDiff(deletedComponents, addedComponents);
    }

    @AuraEnabled
    public static List<ComponentSearchWrapper> queryExistingMembers(String backlogItemId) {
        List<ComponentSearchWrapper> existingSavedMembers = new List<ComponentSearchWrapper>();

        List<Backlog_Component__c> members = ComponentDocServices.getDocumentedComponents(backlogItemId);

        // Iterate through each Backlog Component and create the Wrapper record
        for (Backlog_Component__c backlogComponent : members) {
            addDocumentedComponent(existingSavedMembers, backlogComponent);
        }
        return existingSavedMembers;
    }

    public static List<ComponentSearchWrapper>
                    queryExistingMembersPaginated(String backlogItemId, Integer offset, Integer pageSize) {
        List<ComponentSearchWrapper> existingSavedMembers = new List<ComponentSearchWrapper>();

        List<Backlog_Component__c> members =
            ComponentDocServices.getDocumentedComponentsPaginated(backlogItemId, offset, pageSize);
        for (Backlog_Component__c backlogComponent : members) {
            addDocumentedComponent(existingSavedMembers, backlogComponent);
        }
        return existingSavedMembers;
    }

    @AuraEnabled
    public static List<String> queryDependentMembers(List<String> existingMembersStrings, 
                                                          String relatedComponentsFilterChoice) {
        List<DependentComponentWrapper> dependentSavedMembers = new List<DependentComponentWrapper>();
        List<ComponentSearchWrapper> existingMembers = new List<ComponentSearchWrapper>();
        for (Integer i = existingMembersStrings.size() - 1; i >= 0; --i) {
            String existingMembersString = existingMembersStrings.remove(i);

            if (String.IsNotBlank(existingMembersString)) {
                try {
                    existingMembers.addAll(
                        (List<ComponentSearchWrapper>) JSON.deserialize(existingMembersString, List<ComponentSearchWrapper>.class)
                    );
                } catch(JSONException e) {
                    throw new AuraHandledException(System.Label.Generic_Error + ' \n'+ e.getMessage());
                }
            }
        }
        dependentSavedMembers = DependentComponentServices.constructDependentComponents(existingMembers, relatedComponentsFilterChoice);
        existingMembers.clear();

        Integer chunkSize = 100;
        List<String> dependentSavedMembersJsons = new List<String>();
        if (dependentSavedMembers.size() > chunkSize) {
            List<DependentComponentWrapper> dependentSavedMembersChunk = new List<DependentComponentWrapper>();
            for (Integer i = dependentSavedMembers.size() - 1; i >= 0; --i) {
                dependentSavedMembersChunk.add(dependentSavedMembers.remove(i));
                if (Math.mod(i, chunkSize) == 0) {
                    dependentSavedMembersJsons.add(JSON.serialize(dependentSavedMembersChunk));
                    dependentSavedMembersChunk.clear();
                }
            }
        } else {
            dependentSavedMembersJsons.add(JSON.serialize(dependentSavedMembers));
        }

        return dependentSavedMembersJsons;
    }

    /**
    * Returns a map of profiledata {
    *    'profileSelections' => List<ComponentDocProfile>
    *    'documentedComponentsJSON' => documented component json string
    *  }
    */
    @AuraEnabled
    public static Map<String, Object> getProfileData(String backlogItemId) {
        List<ComponentDocProfile> profileSelections = new List<ComponentDocProfile>();

        List<Backlog_Component__c> backlogComponents = [
            SELECT Component__c, Component__r.Name, Component__r.Full_Name__c, Component__r.Type__c, Backlog__c,
             Profile__c, Profile__r.Name, Profile__r.Full_Name__c, Profile_Permission__c, Source_Instance__r.Name,
            Profile_Data_1__c, Profile_Data_2__c, Include_Entire_Profile__c, Source_Sandbox__c
            FROM Backlog_Component__c
            WHERE Backlog__c = :backlogItemId
                AND (Component__r.Type__c = 'Profile' OR Profile_Permission__c = true)
        ];

        Map<String, Backlog_Component__c> profileNameToBacklogComponent = new Map<String, Backlog_Component__c>();
        for (Backlog_Component__c backlogComponent : backlogComponents) {
            if (backlogComponent.Profile_Permission__c) {
                String profileKey = getInstanceName(backlogComponent) + '#|#' + backlogComponent.Profile__r.Name;
                if (!profileNameToBacklogComponent.containsKey(profileKey)) {
                    profileNameToBacklogComponent.put(profileKey, backlogComponent);
                }
            } else {
                profileNameToBacklogComponent.put(backlogComponent.Component__r.Name, backlogComponent);
            }
        }

        for (Backlog_Component__c component : profileNameToBacklogComponent.values()) {
            profileSelections.add(new ComponentDocProfile(component));
        }

        profileSelections.sort();

        String documentedComponentsJSON = JSON.serialize(
            ProfileServices.getPermissionsMap(queryExistingMembers(backlogItemId))
        );

        Map<String, Object> profileData = new Map<String, Object>();
        profileData.put('profileSelections', profileSelections);
        profileData.put('documentedComponentsJSON', documentedComponentsJSON);

        return profileData;
    }

    @AuraEnabled
    public static void deleteSelectedComponents(List<Id> backlogComponentIds) {
        List<Backlog_Component__c> recordsToDelete = new List<Backlog_Component__c>();
        for (Id backlogComponentId : backlogComponentIds) {
            recordsToDelete.add(new Backlog_Component__c(Id = backlogComponentId));
        }
        if( !recordsToDelete.isEmpty() ) {
            try {
                delete recordsToDelete;
            } catch (DMLException ex) {
                ALMLogServices.error(ex, ALMLogServices.Application.COMPONENT_DOCUMENTATION);
                throw new AuraHandledException(ex.getMessage());
            }
        }
    }

    @AuraEnabled
    public static void updateComponentNotes(Id backlogComponentId, String notes) {
        updateBacklogComponent(
            new Backlog_Component__c(Id = backlogComponentId, Notes__c = notes)
        );
    }

    @AuraEnabled
    public static void updateComponentDeployManually(Id backlogComponentId, Boolean deployManually) {
        updateBacklogComponent(
            new Backlog_Component__c(Id = backlogComponentId, Deploy_Manually__c = deployManually)
        );
    }

    @AuraEnabled
    public static void saveDocumentedProfile(String backlogComponentId, String selectedPermissionsJSON, Boolean includeEntireProfile, Boolean autoIncludeDocumentedComponents) {
        Backlog_Component__c profile = new Backlog_Component__c(Id = backlogComponentId);

        profile.Profile_Permission__c = autoIncludeDocumentedComponents;
        profile.Include_Entire_Profile__c = includeEntireProfile;
        ProfilePermissions.setProfilePermissionsData(profile, selectedPermissionsJSON);

        updateBacklogComponent(profile);
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

    /**
    * Adds the documented component to the given List<ComponentSearchWrapper>
    */
    private static void addDocumentedComponent(List<ComponentSearchWrapper> documentedComponents,
         Backlog_Component__c backlogComponent) {

        Datetime lastModifiedDate = null;
        String lastModifiedBy = '';

        if (backlogComponent.Component__r.Field_Modified_Data__c != null) {
            List<FieldModifiedData> fieldModifiedData = (List<FieldModifiedData>) JSON.deserialize(
                backlogComponent.Component__r.Field_Modified_Data__c, List<FieldModifiedData>.class);

            for (FieldModifiedData o : fieldModifiedData) {

                lastModifiedDate = o.lastModifiedDate;
                lastModifiedBy = o.lastModifiedByName;

                if (o.environmentName.equalsIgnoreCase( getInstanceName(backlogComponent) )) {
                    ComponentSearchWrapper.addWrapper(documentedComponents, backlogComponent, backlogComponent.Component__r,
                        o.environmentName, lastModifiedDate, lastModifiedBy, backlogComponent.Deleted__c);
                    break;
                }
            }
        } else {
            ComponentSearchWrapper.addWrapper(documentedComponents, backlogComponent, backlogComponent.Component__r,
                backlogComponent.Source_Sandbox__c, lastModifiedDate, lastModifiedBy, backlogComponent.Deleted__c);
        }
    }

    private static void updateBacklogComponent(Backlog_Component__c component) {
        try {
            update component;
        } catch (DMLException ex) {
            ALMLogServices.error(ex, ALMLogServices.Application.COMPONENT_DOCUMENTATION);
            throw new AuraHandledException(ex.getMessage());
        }
    }

    private static String getInstanceName(Backlog_Component__c backlogComponent) {
        String instanceName = backlogComponent.Source_Instance__r.Name;

        // If the instance lookup value is null or empty, use the deprecreted Source_Sandbox__c picklist value
        // This is needed to reload existing saved components that might not have the lookup value populated
        return String.isEmpty(instanceName) ? backlogComponent.Source_Sandbox__c : instanceName;
    }

    @AuraEnabled
    public static ProfileTemplate getProfileTemplate(String instanceName) {
        return ProfileServices.retrieveProfileTemplate(instanceName);
    }

    public class DocumentedComponentDiff {
        @AuraEnabled
        public List<String> deletedComponents;

        @AuraEnabled
        public List<ComponentSearchWrapper> addedComponents;

        public DocumentedComponentDiff(List<String> deletedComponents, List<ComponentSearchWrapper> addedComponents) {
            this.deletedComponents = deletedComponents;
            this.addedComponents = addedComponents;
        }
    }

    public class DocumentedComponentsQueryResult {
        @AuraEnabled
        public List<ComponentSearchWrapper> results;
        @AuraEnabled
        public Boolean hasMore;
        @AuraEnabled
        public Integer totalDocumentedComponents;

        public DocumentedComponentsQueryResult() {}
    }
}
