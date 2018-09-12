public with sharing class ProfileTemplate {

    public static final String APPLICATION_TOKEN = 'ProfileTemplate';

    @auraEnabled
    public String instanceName;
    @auraEnabled
    public List<Section> sections;

    public ProfileTemplate(String instanceName, List<Section> sections) {
        this.instanceName = instanceName;
        this.sections = sections;
    }

    public class Section implements Comparable {
        @auraEnabled
        public String label;
        @auraEnabled
        public String apiName;
        @auraEnabled
        public String helpText;
        @auraEnabled
        public List<Permission> permissions;
        @auraEnabled
        public List<Permission> standardPermissions;
        @auraEnabled
        public List<Permission> customPermissions;
        @auraEnabled
        public Boolean hasSubsections;
        @auraEnabled
        public Integer order;

        public Section(Profile_Permission_Data__mdt permissionData) {
            this.label = permissionData.Option_Label__c;
            this.apiName = permissionData.Option_Value__c;
            this.helpText = permissionData.Help_Text__c;
            this.hasSubsections = permissionData.Has_Sub_Sections__c;
            this.permissions = new List<Permission>();
            this.standardPermissions = new List<Permission>();
            this.customPermissions = new List<Permission>();
            this.order = Integer.valueOf(permissionData.Order__c);
        }

        public void addPermissions(List<Permission> permissionsToAdd) {
            if (hasSubsections) {
                for (Permission permission : permissionsToAdd) {

                    if (apiName == ProfileServices.LAYOUT_API_NAME) {
                        String objectName = permission.apiName.split('-')[0];
                        //ignore layouts with null parent object such as the Global Layout
                        if (String.isBlank(objectName)) {
                            continue;
                        }
                        addPermission(permission, objectName);
                    } else if (apiName == ProfileServices.TABS_API_NAME) {
                        if (permission.apiName.startsWithIgnoreCase('standard-')){
                            standardPermissions.add(permission);
                        } else {
                            customPermissions.add(permission);
                        }
                    } else if (apiName == ProfileServices.RECORD_TYPE_API_NAME) {
                        String parentApiName = permission.apiName.split('\\.')[0];
                        addPermission(permission, parentApiName);
                    } else {
                        addPermission(permission, permission.apiName);
                    }
                }
            } else {
                permissions.addAll(permissionsToAdd);
            }
        }

        private void addPermission(Permission permission, String name) {
            if (name.endsWithIgnoreCase('__c') || name.endsWithIgnoreCase('__mdt')) {
                customPermissions.add(permission);
            } else {
                standardPermissions.add(permission);
            }
        }

        public String getKey() {
            return apiName + ':' + label;
        }

        public void sort() {
            permissions.sort();
            standardPermissions.sort();
            customPermissions.sort();
        }

        public Integer compareTo(Object compareTo) {
           Section compareToSection = (Section) compareTo;
            if (order == null && compareToSection.order == null) {
                if (label == compareToSection.label) {
                    return 0;
                } else if (label < compareToSection.label) {
                    return -1;
                } else {
                    return 1;
                }
            } else {
                if (order == compareToSection.order) {
                    return 0;
                } else if (order < compareToSection.order) {
                    return -1;
                } else {
                    return 1;
                }
            }
        }
    }

    public class Permission implements Comparable {
        @auraEnabled
        public String label;
        @auraEnabled
        public String apiName;
        private Integer order;

        public Permission(Profile_Permission_Data__mdt permissionData) {
            this.label = permissionData.Option_Label__c;
            this.apiName = permissionData.Option_Value__c;
            this.order = Integer.valueOf(permissionData.Order__c);
        }
        public Permission(Component__c component) {

            if (component.Type__c == ComponentServices.LAYOUT_ALM_NAME ||
                component.Type__c == ComponentServices.RECORD_TYPE_ALM_NAME)
            {
                this.label = String.format('[{0}] {1}',
                    new String[] {component.Parent_Component__r.Name, component.Name});
            } else {
                this.label = component.Name;
            }
            this.apiName = getApiName(component.Name, component.Type__c, component.Parent_Component__r.Name);
        }

        public Integer compareTo(Object compareTo) {
           Permission compareToPermission = (Permission) compareTo;
            if (order == null && compareToPermission.order == null) {
                if (label == compareToPermission.label) {
                    return 0;
                } else if (label < compareToPermission.label) {
                    return -1;
                } else {
                    return 1;
                }
            } else {
                if (order == compareToPermission.order) {
                    return 0;
                } else if (order < compareToPermission.order) {
                    return -1;
                } else {
                    return 1;
                }
            }
        }
    }

    public class ProfileTemplateState implements State.IStateful {

        private ProfileTemplate template;

        public ProfileTemplateState(String instanceName) {
            this.template = new ProfileTemplate(instanceName, null);
        }

        public ProfileTemplateState(ProfileTemplate profileTemplate) {
            this.template = profileTemplate;
        }

        public String getStateToken() {
            return APPLICATION_TOKEN + State.STATE_TOKEN_DELIM + template.instanceName;
        }

        public String serialize() {
            return JSON.serialize( template );
        }
        public void deserialize( String state ) {
            this.template = (ProfileTemplate) JSON.deserialize( state, ProfileTemplate.class );
        }

        public ProfileTemplate getTemplate() {
            return template;
        }
    }

    public static String getApiName(String name, String type, String parent) {
        String apiName = '';

        if (type == ComponentServices.LAYOUT_ALM_NAME) {
            parent = parent == null ? '' : parent;
            apiName = parent + '-' + name;
        } else if (type == ComponentServices.FIELD_ALM_NAME ||
                   type == ComponentServices.RECORD_TYPE_ALM_NAME) {
            parent = parent == null ? '' : parent;
            apiName = parent + '.' + name;
        } else {
            apiName = name;
        }

        return apiName;
    }

    public static ProfileTemplate mergeTemplates(List<ProfileTemplate> templates) {

        if (templates.isEmpty()) {
            return null;
        }

        ProfileTemplate mergedTemplate = templates[0];

        Map<String, Section> sectionMap = new Map<String, Section>();

        for(Section section : mergedTemplate.sections) {
            sectionMap.put(section.getKey(), section);
        }

        for (Integer i = 1; i < templates.size(); i++) {
            ProfileTemplate templateToMerge = templates[i];
            for (Section section : templateToMerge.sections) {
                Section targetSection = sectionMap.get(section.getKey());
                if (targetSection == null) {
                    sectionMap.put(section.getKey(), section);
                } else {
                    mergePermissions(targetSection.permissions, section.permissions);
                    mergePermissions(targetSection.customPermissions, section.customPermissions);
                    mergePermissions(targetSection.standardPermissions, section.standardPermissions);
                }
            }
        }

        mergedTemplate.sections = sectionMap.values();
        mergedTemplate.sections.sort();

        for(Section section : mergedTemplate.sections) {
            section.sort();
        }

        return mergedTemplate;
    }

    private static void mergePermissions(List<Permission> targetPermissions, List<Permission> permissionsToMerge) {

        Map<String, Permission> permissions = new Map<String, Permission>();
        for (Permission permission : targetPermissions) {
            permissions.put(permission.apiName, permission);
        }

        for(Permission permission : permissionsToMerge) {
            if (!permissions.containsKey(permission.apiName)) {
                targetPermissions.add(permission);
            }
        }
    }
}