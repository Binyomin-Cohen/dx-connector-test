public with sharing class ProfileServices {

    public static final String PROFILE_NAME_INSTANCE_DELIMETER = '~|~';
    public static final String APEX_API_NAME = 'classAccesses';
    public static final String LAYOUT_API_NAME = 'layoutAssignments';
    public static final String FIELD_API_NAME = 'fieldPermissions';
    public static final String OBJECT_API_NAME = 'objectPermissions';
    public static final String RECORD_TYPE_API_NAME = 'recordTypeVisibilities';
    public static final String TABS_API_NAME = 'tabVisibilities';

    public static final Map<String, String> CATEGORY_TO_COMPONENT_TYPE = new Map<String, String> {
          'applicationVisibilities' => 'Application',
          APEX_API_NAME => ComponentServices.APEX_ALM_NAME,
          'pageAccesses' => 'Visualforce Page',
          TABS_API_NAME => 'Custom Object Tab|Web Tab|Visualforce Tab',
          FIELD_API_NAME => ComponentServices.OBJECT_ALM_NAME,
          LAYOUT_API_NAME => ComponentServices.LAYOUT_ALM_NAME,
          OBJECT_API_NAME => ComponentServices.OBJECT_ALM_NAME,
          RECORD_TYPE_API_NAME => ComponentServices.RECORD_TYPE_ALM_NAME
    };

    public static final Map<String, String> COMPONENT_TYPE_TO_CATEGORY = new Map<String, String> {
          'Application' => 'applicationVisibilities',
          ComponentServices.APEX_ALM_NAME => APEX_API_NAME,
          ComponentServices.LAYOUT_ALM_NAME => LAYOUT_API_NAME,
          ComponentServices.FIELD_ALM_NAME => FIELD_API_NAME,
          'Visualforce Page' => 'pageAccesses',
          'Custom Object Tab' => TABS_API_NAME,
          'Web Tab' => TABS_API_NAME,
          'Visualforce Tab' => TABS_API_NAME,
          ComponentServices.OBJECT_ALM_NAME => OBJECT_API_NAME,
          ComponentServices.RECORD_TYPE_ALM_NAME => RECORD_TYPE_API_NAME
    };

    public static List<Backlog_Component__c> getProfileBacklogComponents(String backlogItemId) {
        return [
            SELECT Id, Component__c, Profile__c, Source_Instance__c, Profile_Data_1__c, Profile_Data_2__c
            FROM Backlog_Component__c
            WHERE Backlog__c = :backlogItemId
            AND  (Profile_Permission__c = true
            OR Component__r.Type__c = 'Profile')
        ];
    }

    public static ProfileTemplate generateProfileTemplate(String instanceName) {
        List<Profile_Permission_Data__mdt> categories = getProfilePermissionData(true);

        List<Profile_Permission_Data__mdt> options = getProfilePermissionData(false);

        Map<String, List<ProfileTemplate.Permission>> categoryToPermissions = new Map<String, List<ProfileTemplate.Permission>>();

        for(Profile_Permission_Data__mdt option : options) {
            if (!categoryToPermissions.containsKey(option.Category__c)) {
                categoryToPermissions.put(option.Category__c, new List<ProfileTemplate.Permission>());
            }
            categoryToPermissions.get(option.Category__c).add( new ProfileTemplate.Permission(option) );
        }

        Map<String, List<ProfileTemplate.Permission>> typeToComponent = mapPermissionsByComponentType(instanceName);

        List<ProfileTemplate.Section> sections = new List<ProfileTemplate.Section>();

        for (Profile_Permission_Data__mdt category : categories) {
            ProfileTemplate.Section section = new ProfileTemplate.Section(category);
            sections.add(section);

            if (categoryToPermissions.containsKey(section.label)) {
                section.addPermissions( categoryToPermissions.get(section.label) );
            }

            if (CATEGORY_TO_COMPONENT_TYPE.containsKey( section.apiName )) {
                for (String componentType : CATEGORY_TO_COMPONENT_TYPE.get( section.apiName ).split('\\|')) {
                    if (typeToComponent.containsKey( componentType )) {
                        section.addPermissions( typeToComponent.get(componentType) );
                    }
                }
            }
            section.sort();
        }

        return new ProfileTemplate(instanceName, sections);
    }

    public static List<Profile_Permission_Data__mdt> getProfilePermissionData(Boolean getCategories) {
        return [
            SELECT Id, DeveloperName, Is_Category__c, Help_Text__c, Category__c, Order__c, Option_Label__c, Option_Value__c, Has_Sub_Sections__c
            FROM Profile_Permission_Data__mdt
            WHERE Is_Category__c = :getCategories
            ORDER BY Order__c
        ];
    }

    public static ProfileTemplate retrieveProfileTemplate(String instanceName) {
        try {
            ProfileTemplate.ProfileTemplateState cachedState = new ProfileTemplate.ProfileTemplateState(instanceName);
            ProfileServices.getCache().getData( cachedState );

            return cachedState.getTemplate();
        } catch(State.StateException se) {
            System.debug(se.getMessage());
            return refreshProfileTemplateCache(instanceName);
        }
    }

    public static ProfileTemplate retrieveProfileTemplate(List<String> instanceNames) {
        List<ProfileTemplate> templatesToMerge = new List<ProfileTemplate>();
        for (String instanceName : instanceNames) {
            templatesToMerge.add(retrieveProfileTemplate(instanceName));
        }

        return ProfileTemplate.mergeTemplates(templatesToMerge);
    }

    @future
    public static void refreshProfileTemplateCacheInFuture(String instanceId) {
        Instances__c instance = InstanceServices.getInstance(instanceId);

        if (instance == null) {
            ALMLogServices.error(new ALMException('No instance id specified'), ALMLogServices.Application.SCAN);
            return;
        }

        refreshProfileTemplateCache(instance.Name);
    }

    public static ProfileTemplate refreshProfileTemplateCache(String instanceName) {

        ProfileTemplate template = generateProfileTemplate(instanceName);

        ProfileTemplate.ProfileTemplateState cachedState = new ProfileTemplate.ProfileTemplateState(template);
        try {
            ProfileServices.getCache().putData(cachedState);
        } catch (State.StateException stateException) {
            ALMLogServices.error(stateException, ALMLogServices.Application.SCAN);
        }

        return template;
    }

    /**
    * Retrieve the profile name from a provided build component.
    * @param buildComponent
    * @return String    Profile Name
    */
    public static String getProfileName(Build_Component__c buildComponent) {
        String profileName;

        if (!String.isBlank(buildComponent.Component_Name__c)) {
            profileName = buildComponent.Component_Name__c;
        }
        else if (!String.isBlank(buildComponent.Backlog_Component__r.Profile__r.Name)) {
            //check Backlog_Component__r.Profile__r for backwards compatibility. From now on the
            //component lookup should always be valid for profiles
            profileName = buildComponent.Backlog_Component__r.Profile__r.Name;
        } else {
            profileName = ComponentServices.getComponentName(buildComponent.Component__r);
        }

        return profileName;
    }

    /**
    * Maps component by permission category and API name, removing the instance name.
    * @param components - The components to map.
    * @return Map<String, Set<String>> - A map of the components to the set of API permissions.
    */
    public static Map<String, Set<String>> filterComponents(List<ComponentSearchWrapper> components) {
        List<AssemblerManifestRecord> componentManifestRecords = new List<AssemblerManifestRecord>();
        for (ComponentSearchWrapper component : components) {
            componentManifestRecords.add(new AssemblerManifestRecord(component));
        }

        return filterComponents(componentManifestRecords);
    }

    /**
    * Maps component by permission category and API name, removing the instance name.
    * @param components - The components to map.
    * @return Map<String, Set<String>> - A map of the components to the set of API permissions.
    */
    public static Map<String, Set<String>> filterComponents(List<AssemblerManifestRecord> components) {
        Map<String, Set<String>> filteredMap = new Map<String, Set<String>>();
        Map<String, Set<String>> permissionMap = ProfileServices.getPermissionsMap(components);

        for (String section : permissionMap.keySet()) {
            filteredMap.put(section, new Set<String>());
            for (String permission : permissionMap.get(section)) {
                String parsedPermission = permission.split(ProfileServices.PROFILE_NAME_INSTANCE_DELIMETER)[0];
                filteredMap.get(section).add(parsedPermission);
            }
        }

        return filteredMap;
    }

   /**
    * Map components by permission category and api name
    * @param components
    * @return Map<String, Set<String>> map of profile section apiName => Set of api permissions
    */
    public static Map<String, Set<String>> getPermissionsMap(List<ComponentSearchWrapper> components) {
        List<List<String>> componentStrings = new List<List<String>>();

        for (ComponentSearchWrapper component : components) {
            componentStrings.add(new List<String> {component.componentName, component.component.Type__c, component.component.Parent_Component__r.Name, component.environment});
        }

        return getPermissionsMap(componentStrings);
    }

   /**
    * Map components by permission category and api name
    * @param components
    * @return Map<String, Set<String>> map of profile section apiName => Set of api permissions
    */
    public static Map<String, Set<String>> getPermissionsMap(List<AssemblerManifestRecord> components) {
        List<List<String>> componentStrings = new List<List<String>>();

        for (AssemblerManifestRecord component : components) {
            componentStrings.add(new List<String> {component.getName(), component.getType(), component.getParent(), component.instance});
        }

        return getPermissionsMap(componentStrings);
    }

    /**
    * Map components by permission category and api name
    * @param components   a list of the form [[component name, component type, component parent name, instance],...]
    * @return Map<String, Set<String>> map of profile section apiName => Set of api permissions
    */
    private static Map<String, Set<String>> getPermissionsMap(List<List<String>> components) {
        Map<String, Set<String>> sectionToPermissions = new Map<String, Set<String>>();

        for (List<String> component : components) {
            String name = component[0];
            String type = component[1];
            String parent = component[2];
            String instance = component[3];

            String apiNames = COMPONENT_TYPE_TO_CATEGORY.get(type);

            if (apiNames != null) {
                for (String sectionApiName : apiNames.split('\\|')) {
                    if (!sectionToPermissions.containsKey(sectionApiName)) {
                        sectionToPermissions.put(sectionApiName, new Set<String>());
                    }
                    String apiName = ProfileTemplate.getApiName(name, type, parent);

                    //For now we are only selecting the object if a field is documented.
                    if (type == ComponentServices.FIELD_ALM_NAME) {
                        apiName = parent;
                    }

                    sectionToPermissions.get(sectionApiName).add(apiName + PROFILE_NAME_INSTANCE_DELIMETER + instance);
                }
            }
        }

        return sectionToPermissions;
    }

    /**
    * Creates a map of Component__c.Type => List<ProfileTemplate.Permission> with the ProfileTemplate.Permission
    * representing a Component__c record
    */
    private static Map<String, List<ProfileTemplate.Permission>> mapPermissionsByComponentType(String instanceName) {
        Map<String, List<ProfileTemplate.Permission>> typeToComponent = new Map<String, List<ProfileTemplate.Permission>>();

        Set<String> componentTypes = new Set<String>();

        for(String componentType : CATEGORY_TO_COMPONENT_TYPE.values()) {
            componentTypes.addAll(componentType.split('\\|'));
        }

        for (Component__c component : [
            SELECT Name, Type__c, Parent_Component__c, Parent_Component__r.Name
            FROM Component__c
            WHERE Type__c IN :componentTypes
            AND Source_Instances__c INCLUDES (:instanceName)
         ]) {
            if (!typeToComponent.containsKey(component.Type__c)) {
                typeToComponent.put(component.Type__c, new List<ProfileTemplate.Permission>());
            }
            typeToComponent.get(component.Type__c).add( new ProfileTemplate.Permission(component) );
         }

         return typeToComponent;
    }

    public interface Cacheable {
        void putData(State.IStateful state);
        String getData(State.IStateful state);
    }

    public class StateCache implements Cacheable {

        /**
        * @throws a State.StateException
        */
        public void putData(State.IStateful templateState) {
            State.store(templateState);
        }

        public String getData(State.IStateful templateState) {
            State.retrieve(templateState);
            return templateState.serialize();
        }
    }

    public static Cacheable getCache() {
        //TODO: use platform cache if it is available
        return new StateCache();
    }
}