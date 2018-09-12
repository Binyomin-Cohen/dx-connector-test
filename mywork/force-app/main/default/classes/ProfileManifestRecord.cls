public with sharing class ProfileManifestRecord extends AssemblerManifestRecord implements Comparable {

    public Boolean includeOnlyDocumentedComponents {get; set;}
    public Boolean includeEntireProfile {get; set;}
    public String profileName {get; set;}
    public String selectedPermissions {get; set;}

    public ProfileManifestRecord(Backlog_Component__c backlogComponent) {
        super(backlogComponent);
        this.profileName = backlogComponent.Profile__r.Name;
        this.buildComponent.Component__c = backlogComponent.Profile__c;
        this.buildComponent.Is_Profile__c = true;
        this.buildComponent.Component_Name__c = profileName;
        this.selected = true;
        this.componentId = backlogComponent.Profile__c;
        this.includeEntireProfile = backlogComponent.Include_Entire_Profile__c;
        this.includeOnlyDocumentedComponents = backlogComponent.Profile_Permission__c;
    }

     /**
     * Creates a ProfileManifestRecord from an existing Build_Component__c
     */
     public ProfileManifestRecord(Build_Component__c buildComponent, String profileName) {
        super(buildComponent);
        this.profileName = profileName;
        this.selected = (buildComponent.Type__c != REMOVED);
        this.componentId = buildComponent.Component__c;
        this.includeOnlyDocumentedComponents = buildComponent.Include_Documented_Components__c;
        this.includeEntireProfile = buildComponent.Include_Entire_Profile__c;

        ProfilePermissions permissions = ProfilePermissions.valueOf(buildComponent);
        permissions.name = this.profileName;

        this.selectedPermissions = JSON.serialize(permissions);
     }

     /**
     * Creates a profile manifest record from a component. This record will be considered
     * Undocumented.
     */
     public ProfileManifestRecord(Component__c component) {
        super(new ComponentSearchWrapper(component, '', '', null, '', false));
        this.profileName = ComponentServices.getComponentName(component);
        this.buildComponent.Is_Profile__c = true;
        this.selected = false;
        this.includeOnlyDocumentedComponents = true;
        this.includeEntireProfile = false;
        this.selectedPermissions = '';
     }

     /**
     * Sort by Name ascending
     */
    public Integer compareTo(Object compareTo) {
        ProfileManifestRecord that = (ProfileManifestRecord) compareTo;
        if (this.profileName == that.profileName) {
            return 0;
        }
        else if (this.profileName < that.profileName) {
            return -1;
        }
        else {
            return 1;
        }
    }

    public override Build_Component__c getBuildComponent() {

        buildComponent.Include_Documented_Components__c = includeOnlyDocumentedComponents;
        buildComponent.Include_Entire_Profile__c = includeEntireProfile;

        ProfilePermissions.setProfilePermissionsData(buildComponent, selectedPermissions);

        return buildComponent;
    }

    public override String getKey() {
        return super.getKey() + '|' + profileName;
    }
}