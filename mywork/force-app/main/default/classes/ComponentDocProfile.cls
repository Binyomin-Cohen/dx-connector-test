/**
* Represents a documented profile in component documetation
*/
public class ComponentDocProfile implements Comparable {
    @AuraEnabled
    public Boolean includeOnlyDocumentedComponents { get; set; }
    @AuraEnabled
    public Boolean includeEntireProfile { get; set; }
    @AuraEnabled
    public Boolean selected { get; set; }
    @AuraEnabled
    public Id profileComponentId { get; set; }
    @AuraEnabled
    public String instanceName { get; set; }
    @AuraEnabled
    public String profileName { get; set; }
    @AuraEnabled
    public String selectedPermissions { get; set;}

    private Backlog_Component__c backlogComponent;

    public ComponentDocProfile(Backlog_Component__c backlogComponent) {
        if (backlogComponent.Profile_Permission__c) {
            this.profileName = ComponentServices.getComponentName(backlogComponent.Profile__r);
            this.profileComponentId = backlogComponent.Profile__c;
            this.includeOnlyDocumentedComponents = true;
        } else {
            this.profileName = ComponentServices.getComponentName(backlogComponent.Component__r);
            this.profileComponentId = backlogComponent.Component__c;
            this.includeOnlyDocumentedComponents = false;
        }

        this.includeEntireProfile = backlogComponent.Include_Entire_Profile__c;

        this.selected = true;
        this.instanceName = String.isEmpty(backlogComponent.Source_Instance__r.Name) ?
                backlogComponent.Source_Sandbox__c : backlogComponent.Source_Instance__r.Name;
        this.backlogComponent = new Backlog_Component__c(Id=backlogComponent.Id, Backlog__c=backlogComponent.Backlog__c);
        this.backlogComponent.Source_Sandbox__c = this.instanceName;

        if (backlogComponent.Id == null) {
            this.backlogComponent.Component__c=profileComponentId;
        } else if (String.isBlank(instanceName) && backlogComponent.Component__c != profileComponentId) {
            //For legacy profile cleanup, create a new component that looks up to the profile component so all others can be deleted
            this.backlogComponent = backlogComponent.clone(false, true);
            this.backlogComponent.Component__c=profileComponentId;
        }

        this.backlogComponent.Source_Instance__c = backlogComponent.Source_Instance__c;

        this.selectedPermissions = ProfilePermissions.getProfilePermissionsString(backlogComponent);
    }

    public ComponentDocProfile(Backlog_Component__c backlogComponent, Boolean includeOnlyDocumentedComponents) {
        this(backlogComponent);
        if (includeOnlyDocumentedComponents) {
            this.includeOnlyDocumentedComponents = includeOnlyDocumentedComponents;
            backlogComponent.Profile_Permission__c = true;
            backlogComponent.Profile__c = profileComponentId;
        }
    }

    @AuraEnabled
    public String getBacklogComponentId() {
        return backlogComponent.Id;
    }

    /**
    * @throws ALMException
    */
    public Backlog_Component__c getBacklogComponent() {
        backlogComponent.Profile_Permission__c = includeOnlyDocumentedComponents;
        backlogComponent.Profile__c = profileComponentId;
        backlogComponent.Include_Entire_Profile__c = includeEntireProfile;

        ProfilePermissions.setProfilePermissionsData(backlogComponent, selectedPermissions);

        //TODO: discuss need of setting the Source_Sandbox__c field with Jon

        return backlogComponent;
    }

    @AuraEnabled
    public String getKey() {
        String instance = (instanceName == null) ? '' : instanceName;
        return instance + '|' + String.valueOf( profileComponentId );
    }

    public Integer compareTo(Object o) {
        ComponentDocProfile p = (ComponentDocProfile) o;

        if( profileName == p.ProfileName) {
            return 0;
        }
        else if( profileName < p.ProfileName) {
            return -1;
        }
        else {
            return 1;
        }
    }

}
