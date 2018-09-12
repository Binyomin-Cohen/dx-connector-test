public virtual with sharing class AssemblerManifestRecord {

    public static final String DOCUMENTED = 'Documented';
    public static final String UNDOCUMENTED = 'Undocumented';
    public static final String REMOVED = 'Removed';

    public Id backlogId {get; set;}
    public String backlogStatus {get; set;}
    public String backlogName {get; set;}
    public String instance {get; set;}
    public String notes {get; set;}
    public Boolean deployManually {get; set;}
    public Boolean isDeletion {get; set;}
    public Boolean isRemoved {get; set;}
    public Boolean savedIsRemovedValue {get; set;}
    public Boolean selected {get; set;}

    protected Id componentId;
    protected Build_Component__c buildComponent;

    public AssemblerManifestRecord(Backlog_Component__c backlogComponent) {
        this.backlogId          = backlogComponent.Backlog__r.Id;
        this.backlogStatus      = backlogComponent.Backlog__r.Status__c;
        this.backlogName        = backlogComponent.Backlog__r.Name;
        this.instance           = backlogComponent.Source_Instance__r.Name;
        this.notes              = backlogComponent.Notes__c;
        this.componentId        = backlogComponent.Component__c;
        this.deployManually     = backlogComponent.Deploy_Manually__c;

        this.buildComponent = new Build_Component__c(Backlog_Component__c = backlogComponent.Id,
         Type__c = DOCUMENTED, Instance_Name__c = instance, Component__c = backlogComponent.Component__c);
        this.buildComponent.Component_Name__c   = ComponentServices.getComponentName(backlogComponent.Component__r);
        this.buildComponent.Component_Type__c   = backlogComponent.Component__r.Type__c;
        this.buildComponent.Parent_Component__c = backlogComponent.Component__r.Parent_Component__r.Name;
        this.buildComponent.Is_Deletion__c = backlogComponent.Deleted__c;
        this.buildComponent.Is_Manual_Deployment__c = deployManually;
        
        this.isDeletion = backlogComponent.Deleted__c;

        this.selected = false;
        this.isRemoved = deployManually;
        this.savedIsRemovedValue = this.isRemoved;
        buildComponent.Backlog_Component__r = null;
        buildComponent.Component__r = null;
    }

    public AssemblerManifestRecord(ComponentSearchWrapper undocumentedComponent) {
        this.instance                       = undocumentedComponent.environment;
        this.componentId                    = undocumentedComponent.component.Id;
        this.deployManually                 = false;

        buildComponent                      = new Build_Component__c( Type__c = UNDOCUMENTED);
        buildComponent.Component_Name__c    = ComponentServices.getComponentName(undocumentedComponent.component);
        buildComponent.Component_Type__c    = undocumentedComponent.component.Type__c;
        buildComponent.Parent_Component__c  = undocumentedComponent.component.Parent_Component__r.Name;
        buildComponent.Instance_Name__c     = instance;
        buildComponent.Component__c         = undocumentedComponent.component.Id;
        buildComponent.Is_Deletion__c = undocumentedComponent.isDeleted;

        undocumentedComponent.existsOnCurrentBacklog = true;
        selected = false;
        isDeletion = buildComponent.Is_Deletion__c;
        isRemoved = false;
        // Since the component wasn't here before, it is as if it was removed at the last save.
        // By having isRemoved = false and having savedIsRemovedValue = true, we can show the user
        // that there has been a change since the last save.
        this.savedIsRemovedValue = true; 
        buildComponent.Backlog_Component__r = null;
        buildComponent.Component__r = null;
    }

    public AssemblerManifestRecord(Build_Component__c buildComponent) {
        this.buildComponent = buildComponent;
        if (buildComponent.Backlog_Component__c != null) {
            this.backlogId          = buildComponent.Backlog_Component__r.Backlog__r.Id;
            this.backlogStatus      = buildComponent.Backlog_Component__r.Backlog__r.Status__c;
            this.backlogName        = buildComponent.Backlog_Component__r.Backlog__r.Name;
            this.instance           = buildComponent.Backlog_Component__r.Source_Instance__r.Name;
            this.notes              = buildComponent.Backlog_Component__r.Notes__c;
            this.buildComponent.Component_Name__c   = ComponentServices.getComponentName(buildComponent.Backlog_Component__r.Component__r);
            this.buildComponent.Component_Type__c   = buildComponent.Backlog_Component__r.Component__r.Type__c;
            this.buildComponent.Parent_Component__c = buildComponent.Backlog_Component__r.Component__r.Parent_Component__r.Name;
            this.componentId        = buildComponent.Backlog_Component__r.Component__c;
            this.deployManually     = buildComponent.Is_Manual_Deployment__c;
        } else {
            this.componentId        = buildComponent.Component__c;
            this.instance           = buildComponent.Instance_Name__c;
            this.deployManually     = false;
        }
        this.isRemoved = (buildComponent.Type__c == REMOVED
            || (!getIsUndocumented() && buildComponent.Backlog_Component__c == null));
        this.savedIsRemovedValue = this.isRemoved;
        this.isDeletion = buildComponent.Is_Deletion__c;
        this.selected = !isRemoved;
        buildComponent.Backlog_Component__r = null;
        buildComponent.Component__r = null;
    }

    public virtual Boolean getIsDocumented() {
        return buildComponent.Type__c == DOCUMENTED || buildComponent.Type__c == REMOVED;
    }

    public Boolean getIsUndocumented() {
        return buildComponent.Type__c == UNDOCUMENTED;
    }

    public virtual String getKey() {
        String instance = (instance == null) ? '' : instance;
        return instance + '|' + String.valueOf( componentId );
    }

    public virtual String getDocumentedKey() {
        return backlogName == null ? getKey() : getKey() + '|' + backlogName;
    }

    public virtual Build_Component__c getBuildComponent() {
        if (isRemoved) {
            buildComponent.Type__c = AssemblerManifestRecord.REMOVED;
        } else if (getIsDocumented()) {
            buildComponent.Type__c = AssemblerManifestRecord.DOCUMENTED;
        }
        return buildComponent;
    }

    public Id getComponentId() {
        return this.componentId;
    }

    public String getName() {
        return buildComponent.Component_Name__c;
    }

    public String getType() {
        return buildComponent.Component_Type__c;
    }

    public String getParent() {
        return buildComponent.Parent_Component__c;
    }

    public virtual AssemblerManifestRecord deepClone() {
        AssemblerManifestRecord clonedRecord = this.clone();
        clonedRecord.buildComponent = getBuildComponent().clone( false, true );
        return clonedRecord;
    }
}