public with sharing class SprintModel {

    public static final String COMPLETED_STATUS = 'Completed';
    public static final String IN_PROGRESS_STATUS = 'In Progress';
    public static final String INCOMPLETE_STATUS = 'Incomplete';
    public static final String NOT_STARTED_STATUS = 'Planned Items';

    public static String ITEM_COMPLETED_STATUS {
        get {
            if (ITEM_COMPLETED_STATUS == null) {
                List<ALM_Settings_List__c> sprintColumns = ALMSettingsServices.getSprintLaneSettings();
                if (sprintColumns.isEmpty()) {
                    ITEM_COMPLETED_STATUS = '';
                } else {
                    ITEM_COMPLETED_STATUS = sprintColumns[sprintColumns.size() - 1].Value__c;
                }
            }
            return ITEM_COMPLETED_STATUS;
        }
        private set;
    }

    public String name;
    public String sprintId {get; set;}
    public String status {get; set;}
    public String statusLabel {get; set;}
    public String statusClass;
    public String startDateDisplay {get; set;}
    public String endDateDisplay {get; set;}
    public Date startDate {get; set;}
    public Date endDate {get; set;}
    public Boolean isChatterEnabled {
      get {
        return Schema.SObjectType.Sprint__c.isFeedEnabled();
      }
        private set;
    }

    public Boolean hasItemsForReassignment;

    public Integer incompleteItems;
    public Integer itemsForReassignment;
    public Integer totalItems;
    public Decimal totalEffort;
    public Integer unestimatedItems;


    public SprintModel(Sprint__c sprint) {
        sprintId = sprint.Id;
        name = sprint.Name;
        status = sprint.Status__c;
        statusLabel = SprintServices.getStatusPicklistLabel(status);
        statusClass = (sprint.Status__c == null) ? '' : sprint.Status__c.toLowerCase().replaceAll(' ','-');
        startDate = sprint.Start_Date__c;
        startDateDisplay = SprintServices.getSprintDateFormat( sprint.Start_Date__c );
        endDate = sprint.End_Date__c;
        endDateDisplay = SprintServices.getSprintDateFormat( sprint.End_Date__c );

        incompleteItems = 0;
        itemsForReassignment = 0;
        totalItems = 0;
        totalEffort = 0;
        hasItemsForReassignment = false;
        unestimatedItems = 0;
    }

    public void setHasItemsForReassignment() {
        hasItemsForReassignment = (status == COMPLETED_STATUS && itemsForReassignment > 0);
    }
}