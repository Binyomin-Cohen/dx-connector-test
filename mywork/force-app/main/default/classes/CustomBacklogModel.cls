public class CustomBacklogModel {

    public String name;
    public String customBacklogId;
    public String totalItems {get; set;}
    public String unprioritizedItems {get; set;}
    public Boolean isUniversal {get; set;}


    public CustomBacklogModel(Custom_Backlog__c cbklg){
        this.name = cbklg.Name;
        this.isUniversal = cbklg.Universal__c;
        this.customBacklogId = this.isUniversal ? BacklogManagementHomeController.MASTER_BACKLOG_IDENTIFIER : cbklg.Id;
        Integer intUnprioritizedItems = 0;
        for (Backlog__c bItem: cbklg.Backlog_Items__r) {
            if (bItem.Custom_Priority__c == null){
                intUnprioritizedItems += 1;
            }
        }
        if (!this.isUniversal) {
            this.totalItems = getCountAsString(cbklg.Backlog_Items__r.size());
            this.unprioritizedItems = getCountAsString(intUnprioritizedItems);
        }
    }

    public Static String getCountAsString(Integer itemCount) {
        return itemCount > 999? '999+': String.valueOf(itemCount);
    }

}