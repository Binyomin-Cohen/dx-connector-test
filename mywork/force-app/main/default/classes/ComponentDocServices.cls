public with sharing class ComponentDocServices {

    public static final String PROFILE_COMPONENT_TYPE = 'Profile';
    public static final String RECENTLY_MODIFIED_COMPONENTS_CACHE_KEY = 'RECENTLY_MODIFIED_COMPONENTS_CACHE_KEY';
    public static final String RECENTLY_MODIFIED_COMPONENTS_CACHE_ERROR = 'An error occurred while caching component Ids';
    public static Integer RECENTLY_MODIFIED_COMPONENTS_CACHE_LIMIT = 25;

    public static Map<String, Id> instancesMap {
        get {
            if (instancesMap == null) {
                instancesMap = ComponentDocServices.getInstanceMap();
            }
            return instancesMap;
        }

        private set;
    }

    /**
    * @return case insensitive map of instance name => instance Id
    */
    public static Map<String, Id> getInstanceMap() {
        Map<String, Id> instances = new Map<String, Id>();
        for (Instances__c record : InstanceServices.getAllInstances()) {
            String instanceName = record.Name;
            instances.put(instanceName.toLowerCase(), record.Id);
        }
        return instances;
    }

    public static Map<String, String> getRunTimes(){
        Map<String, String> timesMap = new Map<String, String>();
        ALMApplicationResultServices.ResultState storedState = ALMApplicationResultServices.getScanRunTimesCache();
        Map<Id, ALMApplicationResultServices.InstanceWithLatestAndSuccessfulRunTime> storedInstanceToRunTimes = storedState.getInstanceTimes();
        for (ALMApplicationResultServices.InstanceWithLatestAndSuccessfulRunTime storedInstanceToRunTime : storedInstanceToRunTimes.values()) {
            if (storedInstanceToRunTime.latestSuccessfulRuntime != null) {
                timesMap.put(storedInstanceToRunTime.instanceName, storedInstanceToRunTime.latestSuccessfulRuntime.format());
            }
        }
        return timesMap;
    }

    public static List<String> getAvailableUsers(){
        List<String> userStrings = new List<String>(Pluck.strings(ALM_Settings_List__c.Value__c,
             ALMSettingsServices.getAvailableComponentUsersSettings()));
        userStrings.sort();

        return userStrings;
    }

    /**
    * @throws ALMException, DMLException
    */
    public static void createBacklogComponents(String selectedComponentIdString, String backlogItemId, String notes) {
        List<ComponentSearchWrapper> selectedComponents;
        List<Backlog_Component__c> newBacklogComponents = new List<Backlog_Component__c>();

        selectedComponents = ComponentSearch.getSelectedComponents(selectedComponentIdString);

        for(ComponentSearchWrapper wrapper : selectedComponents) {
            Backlog_Component__c backlogComponent = createBacklogComponent(wrapper.component, wrapper.environment, backlogItemId, notes, wrapper.isDeleted, wrapper.deployManually);

            if (wrapper.component.Type__c == PROFILE_COMPONENT_TYPE) {
                ComponentDocProfile profile = new ComponentDocProfile(backlogComponent, true);
                newBacklogComponents.add(profile.getBacklogComponent());
            } else {
                newBacklogComponents.add(backlogComponent);
            }
        }

        insert newBacklogComponents;
        /*
        documentedComponentsJSON = JSON.serialize(
            ProfileServices.getPermissionsMap(existingSavedMembers)
        );
        */
    }

    private static Backlog_Component__c createBacklogComponent(Component__c component, String sourceEnvironment, String backlogItemId, String notes, Boolean isDeleted, Boolean deployManually) {
        Id environmentId = instancesMap.get(sourceEnvironment.toLowerCase());

        Backlog_Component__c backlogComponent = new Backlog_Component__c(Backlog__c=backlogItemId);
        backlogComponent.Notes__c = notes;
        backlogComponent.Component__c = component.Id;
        backlogComponent.Source_Sandbox__c = sourceEnvironment;
        backlogComponent.Deleted__c = isDeleted;
        backlogComponent.Deploy_Manually__c = deployManually;

        if (environmentId != null) {
            backlogComponent.Source_Instance__c = environmentId;

/*            // This is needed to prevent DML exception when trying to save non profile components
            // Cannot specify both an external ID reference Source_Instance__r and a salesforce id, Source_Instance__c
            if (component.Type__c == 'Profile') {
                backlogComponent.Source_Instance__r = new Instances__c(Name=sourceEnvironment);
            }
*/
        }

        return backlogComponent;
    }

    // TODO: this logic was mostly extracted from ComponentSearch. Refactor ComponentSearch to use this.
    public static List<ComponentSearchWrapper> makeComponentSearchWrappers(List<Component__c> components) {
        List<ComponentSearchWrapper> searchWrappers = new List<ComponentSearchWrapper>();
        Set<String> instanceSet = Pluck.strings(Instances__c.Name, InstanceServices.getAllInstances());
        for (Component__c component : components) {
            if (component.Field_Modified_Data__c != null)  {
                List<FieldModifiedData> fieldModifiedData =
                    (List<FieldModifiedData>) JSON.deserialize(component.Field_Modified_Data__c,
                                                               List<FieldModifiedData>.class);
                for (FieldModifiedData fmd : fieldModifiedData) {
                    if(instanceSet.contains(fmd.environmentName)) {
                        searchWrappers.add(new ComponentSearchWrapper(component, fmd));
                    }
                }
            } else {
                // If component doesn't have JSON data, we still need to create a wrapper for the component
                String environmentName = '';
                Datetime lastModifiedDate = null;
                String lastModifiedBy = '';
                String notes = '';
                searchWrappers.add(new ComponentSearchWrapper(component, environmentName, notes, lastModifiedDate,
                                                              lastModifiedBy, false));
            }
        }
        return searchWrappers;
    }

    public static List<Backlog_Component__c> getDocumentedComponents(String backlogItemId) {
        return [
            SELECT Component__c, Component__r.Name, Component__r.Full_Name__c, Component__r.Type__c,
                Component__r.Field_Modified_Data__c, Component__r.Parent_Component__c,
                Component__r.Parent_Component__r.Name, Component__r.Parent_Component__r.Full_Name__c,
                Component__r.Reference_Data_1__c, Component__r.Reference_Data_2__c, Component__r.Reference_Data_3__c,
                Component__r.Reference_Data_4__c, Component__r.Reference_Data_5__c,
                Source_Sandbox__c, Source_Instance__r.Name, Deleted__c, Notes__c, Deploy_Manually__c,
                Profile_Permission__c, Profile_Data_1__c, Profile_Data_2__c, Include_Entire_Profile__c
            FROM Backlog_Component__c
            WHERE Backlog__c =: backlogItemId
            AND Component__r.Type__c != :PROFILE_COMPONENT_TYPE AND Profile_Permission__c = false
            ORDER BY Component__r.Name ASC
        ];
    }

    public static List<Backlog_Component__c> getDocumentedComponentsPaginated(String backlogItemId, Integer offset,
                                                                              Integer pageSize) {
        return [
            SELECT Component__c, Component__r.Name, Component__r.Full_Name__c, Component__r.Type__c,
                Component__r.Field_Modified_Data__c, Component__r.Parent_Component__c,
                Component__r.Parent_Component__r.Name, Component__r.Parent_Component__r.Full_Name__c,
                Component__r.Reference_Data_1__c, Component__r.Reference_Data_2__c, Component__r.Reference_Data_3__c,
                Component__r.Reference_Data_4__c, Component__r.Reference_Data_5__c,
                Source_Sandbox__c, Source_Instance__r.Name, Deleted__c, Notes__c, Deploy_Manually__c, Profile_Permission__c,
                Profile_Data_1__c, Profile_Data_2__c, Include_Entire_Profile__c
            FROM Backlog_Component__c
            WHERE Backlog__c =: backlogItemId
            AND Component__r.Type__c != :PROFILE_COMPONENT_TYPE AND Profile_Permission__c = false
            ORDER BY Component__r.Name ASC
            LIMIT :pageSize OFFSET :offset
        ];
    }

    // TODO: Pull ComponentSearch queries into helper methods in this service class.
    public static List<Component__c> queryComponentsByIds(List<Id> compIds) {
        return [SELECT Id, Name, Full_Name__c, Type__c, Deleted__c, Parent_Component__r.Full_Name__c,
                       Parent_Component__r.Name, Field_Modified_Data__c, Overall_Last_Modified_Date__c
                FROM Component__c
                WHERE Id in :compIds
                ORDER BY Overall_Last_Modified_Date__c DESC NULLS LAST, Id DESC];
    }

    @future
    public static void refreshRecentlyModifiedComponentsCache() {
        cacheRecentlyModifiedComponents(new List<Id>(
                new Map<Id,Component__c>(
                        [SELECT Id, Overall_Last_Modified_Date__c
                         FROM Component__c
                         ORDER BY Overall_Last_Modified_Date__c DESC NULLS LAST, Id DESC
                         LIMIT :RECENTLY_MODIFIED_COMPONENTS_CACHE_LIMIT]
                ).keySet()
        ));
    }

    public static List<Id> getCachedRecentlyModifiedComponents() {
        RecentlyModifiedComponentsCache cache = new RecentlyModifiedComponentsCache();
        try {
            State.retrieve(cache);
        } catch (State.StateException se) {
            return new List<Id>();
        }
        return cache.getIds();
    }

    public static void cacheRecentlyModifiedComponents(List<Id> ids) {
        try {
            RecentlyModifiedComponentsCache cacheIds = new RecentlyModifiedComponentsCache(ids);
            State.store(cacheIds);
        } catch (State.StateException e) {
            throw new ALMException(RECENTLY_MODIFIED_COMPONENTS_CACHE_ERROR + ': ' + e.getMessage());
        }
    }

    public class RecentlyModifiedComponentsCache implements State.IStateful {
        private List<String> recentlyModifiedComponentIds;

        public RecentlyModifiedComponentsCache() {
            this.recentlyModifiedComponentIds = new List<String>();
        }

        public RecentlyModifiedComponentsCache(List<String> recentlyModifiedComponentIds) {
            this.recentlyModifiedComponentIds = recentlyModifiedComponentIds;
        }

        public List<Id> getIds() {
            return recentlyModifiedComponentIds;
        }

        public String getStateToken() {
            return RECENTLY_MODIFIED_COMPONENTS_CACHE_KEY;
        }

        public String serialize() {
            return JSON.serialize(recentlyModifiedComponentIds);
        }

        public void deserialize( String state ) {
            recentlyModifiedComponentIds = (List<String>) JSON.deserialize(state, List<String>.class);
        }
    }
}
