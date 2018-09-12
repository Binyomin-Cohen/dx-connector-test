/**
* Represents a row in the Backlog Management Page
*/
public class BacklogItemRow {
    public Backlog__c record {get; set;}
    private Boolean viewingCustomBacklog { get; private set; }
    public Integer priority {
        
        get {
            if (this.record != null){
                if (viewingCustomBacklog){
                    return Integer.valueOf(this.record.Custom_Priority__c);
                } else {
                    return Integer.valueOf(this.record.Priority__c);
                }
            }
            return null;
        }
        set;
    }
    
    public void savePriority(Integer value){
        if (this.record != null){
            if (viewingCustomBacklog){
                this.record.Custom_Priority__c = value;
            } else {
                this.record.Priority__c = value;
            }
        }
    }

    public BacklogItemRow(Backlog__c record, Boolean viewingCustomBacklog) {
        this.record = record;
        this.viewingCustomBacklog = viewingCustomBacklog;
    }
    
    public BacklogItemRow(Backlog__c record) {
        this(record, false);
    }
}