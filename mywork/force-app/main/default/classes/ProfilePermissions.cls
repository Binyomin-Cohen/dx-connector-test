public with sharing class ProfilePermissions {

    public static final Integer MAX_TEXT_AREA_DATA_LENGTH = 131072;
    public static final Integer DATA_FIELD_COUNT = 2;

    public String name;
    public List<Section> sections;
    public List<String> instances;

    public ProfilePermissions() {
        this.sections = new List<Section>();
        this.instances = new List<String>();
    }

    public ProfilePermissions(Map<String, Set<String>> sectionToPermissions) {
        this.sections = new List<Section>();

        for (String sectionName : sectionToPermissions.keySet()) {
            Section section = new Section();
            section.apiName = sectionName;
            section.permissions =  new List<String>( sectionToPermissions.get(sectionName) );
            sections.add(section);
        }
    }

    public class Section {
        public String apiName;
        public List<String> permissions;
    }

    /**
    * Replaces the object selections in the FLS Section with the documented fields for that object
    * @param objectToDocumentedFields   Map of object name => Set of documented fields on that object
    */
    public void expandFLS(Map<String, Set<String>> objectToDocumentedFields) {
        for (Section section : sections) {
            if (section.apiName == ProfileServices.FIELD_API_NAME) {
                Set<String> fieldPermissions = new Set<String>();
                for (String objectName : section.permissions) {
                    if (objectToDocumentedFields.containsKey(objectName)) {
                        fieldPermissions.addAll( objectToDocumentedFields.get(objectName) );
                    }
                }
                section.permissions = new List<String>(fieldPermissions);
                break;
            }
        }
    }

    public static ProfilePermissions mergePermissions(List<ProfilePermissions> permissions) {
        ProfilePermissions mergedPermissions = new ProfilePermissions();

        Set<String> allInstances = new Set<String>();
        Map<String, Section> sectionMap = new Map<String, Section>();

        for (ProfilePermissions permission : permissions) {
            allInstances.addAll(permission.instances);
            mergedPermissions.name = permission.name;

            for(Section section : permission.sections) {
                if (sectionMap.containsKey(section.apiName)) {
                    Section mergedSection = sectionMap.get(section.apiName);
                    Set<String> sectionPermissions = new Set<String>(mergedSection.permissions);
                    for (String sectionPermission : section.permissions) {
                        if (sectionPermission != null && !sectionPermissions.contains(sectionPermission)) {
                            mergedSection.permissions.add(sectionPermission);
                        }
                    }
                } else {
                    Set<String> sectionPermissions = new Set<String>(section.permissions);
                    sectionPermissions.remove(null);
                    section.permissions = new List<String>(sectionPermissions);
                    sectionMap.put(section.apiName, section);
                }
            }
        }

        mergedPermissions.instances = new List<String>(allInstances);
        mergedPermissions.sections = sectionMap.values();

        return mergedPermissions;
    }
    
    public void selectPermissions(Map<String, Set<String>> sectionToPermissions) {
        Map<String, Section> sectionMap = getSectionMap();
        
        for (String sectionName : sectionToPermissions.keySet()){
            if (sectionMap.containsKey(sectionName)){
                Section sectionRecord = sectionMap.get(sectionName);
                Set<String> sectionPermissions = new Set<String>(sectionRecord.permissions);
                sectionPermissions.addAll(sectionToPermissions.get(sectionRecord.apiName));
                sectionRecord.permissions = new List<String>(sectionPermissions);
            } else {
                Section sectionRecord = new Section();
                sectionRecord.apiName = sectionName;
                sectionRecord.permissions = new List<String>(sectionToPermissions.get(sectionName));
                this.sections.add(sectionRecord);
            }
        }
    }

    public void removePermissions(Map<String, Set<String>> sectionToPermissions) {
        Map<String, Section> sectionMap = getSectionMap();

        for (String sectionName : sectionToPermissions.keySet()) {
            if (sectionMap.containsKey(sectionName)) {
                Section sectionRecord = sectionMap.get(sectionName);
                Set<String> sectionPermissions = new Set<String>(sectionRecord.permissions);
                sectionPermissions.removeAll(sectionToPermissions.get(sectionRecord.apiName));
                sectionRecord.permissions = new List<String>(sectionPermissions);
            }
        }
    }

    public Map<String, Section> getSectionMap() {
        Map<String, Section> sectionMap = new Map<String, Section>();

        for (Section section : this.sections) {
            sectionMap.put(section.apiName, section);
        }

        return sectionMap;
    }

    /**
    * Gets the profile json stored on a record
    * @param   record   Either a Backlog_Component__c or Build_Component__c
    * @return  String   The serialized ProfilePermissions
    */
    public static String getProfilePermissionsString(SObject record) {
        String permissionsString = '';
        for (Integer i = 1; i <= DATA_FIELD_COUNT; i++) {
            String fieldName = SObjectServices.getFullyQualifiedName('Profile_Data_' + i + '__c');
            String value = (String)record.get(fieldName);
            if (value != null) {
                permissionsString += value;
            }
        }

        return permissionsString;
    }

    /**
    * Populates the profile json fields on the passed in record with Profile_Data_i__c fields
    */
    public static void setProfilePermissionsData(SObject record, String permissionData) {
        //clear all profile data
        for (Integer i = 1; i <= DATA_FIELD_COUNT; i++) {
            String fieldName = SObjectServices.getFullyQualifiedName('Profile_Data_' + i + '__c');
            record.put(fieldName, '');
        }

        List<String> permissionDataChunks
            = String.isEmpty(permissionData) ? new List<String>() : State.splitByLength(permissionData, MAX_TEXT_AREA_DATA_LENGTH);

        if (permissionDataChunks.size() > DATA_FIELD_COUNT) {
            throw new ALMException('Profile data could not be stored. Data value to long: ' + String.valueOf(permissionData.length()) );
        }

        for (Integer i = 0; i < permissionDataChunks.size(); i++) {
            String fieldName = SObjectServices.getFullyQualifiedName('Profile_Data_' + (i + 1) + '__c');
            record.put(fieldName, permissionDataChunks[i]);
        }
    }

    public static ProfilePermissions valueOf(Backlog_Component__c backlogComponent) {
        String permissionsJSON = getProfilePermissionsString(backlogComponent);
        ProfilePermissions profile = valueOf(permissionsJSON);
        if (backlogComponent.Source_Instance__r != null) {
            profile.instances = new List<String> { backlogComponent.Source_Instance__r.Name };
        }

        if (String.isBlank(profile.name) && backlogComponent.Component__r != null) {
            profile.name = ComponentServices.getComponentName(backlogComponent.Component__r);
        }

        return profile;
    }

    public static ProfilePermissions valueOf(Build_Component__c buildComponent) {
        String permissionsJSON = getProfilePermissionsString(buildComponent);
        ProfilePermissions profile = valueOf(permissionsJSON);
        if (String.isBlank(profile.name)) {
            profile.name = buildComponent.Component_Name__c;
        }

        return profile;
    }

    public static ProfilePermissions valueOf(String permissionsJSON) {
        if (String.isBlank(permissionsJSON)) {
            return new ProfilePermissions();
        }

        try {
            return (ProfilePermissions)JSON.deserialize(permissionsJSON, ProfilePermissions.class);
        } catch(JSONException je) {
            throw new ALMException(je.getMessage());
        }
    }
}