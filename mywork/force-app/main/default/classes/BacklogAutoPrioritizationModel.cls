public with sharing class BacklogAutoPrioritizationModel {
    public enum PrioritizationBehavior {
        OFF,
        TOP,
        BOTTOM
    }

    public Id backlogId;
    public PrioritizationBehavior behavior {
        get;
        set {
            this.behavior = value != null ? value : getDefaultPrioritizationBehavior();
        }
    }
    public void setBehavior(String behavior) {
        this.behavior = convertPrioritizationBehaviorStringToEnum(behavior);
    }

    public BacklogAutoPrioritizationModel() {
        this.backlogId = BacklogItemServices.UNIVERSAL_BACKLOG_ID;
        this.behavior = null;
    }

    public BacklogAutoPrioritizationModel(Id backlogId) {
        this.backlogId = backlogId;
        this.behavior = null;
    }

    public BacklogAutoPrioritizationModel(PrioritizationBehavior behavior) {
        this.backlogId = BacklogItemServices.UNIVERSAL_BACKLOG_ID;
        this.behavior = behavior;
    }

    public BacklogAutoPrioritizationModel(Id backlogId, PrioritizationBehavior behavior) {
        this.backlogId = backlogId;
        this.behavior = behavior;
    }

    public BacklogAutoPrioritizationModel(Id backlogId, String behavior) {
        this.backlogId = backlogId;
        this.behavior = convertPrioritizationBehaviorStringToEnum(behavior);
    }

    public BacklogAutoPrioritizationModel(Backlog_Auto_Prioritization__c backlogAutoPrioritizationConfiguration) {
        this(backlogAutoPrioritizationConfiguration.Backlog_ID__c, backlogAutoPrioritizationConfiguration.Prioritization_Behavior__c);
    }

    public Backlog_Auto_Prioritization__c getRecord() {
        return new Backlog_Auto_Prioritization__c(
            Name = (this.backlogId == BacklogItemServices.UNIVERSAL_BACKLOG_ID ? 'Universal' : 'Custom_' + this.backlogId),
            Backlog_ID__c = this.backlogId,
            Prioritization_Behavior__c = this.behavior.name()
        );
    }

    public static PrioritizationBehavior convertPrioritizationBehaviorStringToEnum(String behavior) {
        for (PrioritizationBehavior prioritizationBehavior : PrioritizationBehavior.values()) {
            if (prioritizationBehavior.name().equalsIgnoreCase(behavior)) {
                return prioritizationBehavior;
            }
        }

        return null;
    }

    public static PrioritizationBehavior getDefaultPrioritizationBehavior() {
        return PrioritizationBehavior.values()[0];
    }
}