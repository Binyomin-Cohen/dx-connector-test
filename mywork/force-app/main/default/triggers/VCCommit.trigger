trigger VCCommit on VC_Commit__c (before insert) {

    if (Trigger.isBefore && Trigger.isInsert) {
        VCServices.linkBacklogItem(Trigger.new);
    }

}
