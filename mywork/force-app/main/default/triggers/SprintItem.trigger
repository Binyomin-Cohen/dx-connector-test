trigger SprintItem on Sprint_Item__c (after delete, after insert, after undelete, after update) {
    if (!SprintItemServices.RUN_TRIGGER) return;
    
    if (Trigger.isAfter) {
        BacklogItemServices.RUN_TRIGGER = false;
        if (Trigger.isInsert || Trigger.isUpdate || Trigger.isUndelete) {
            SprintItemServices.updateCurrentSprintOnBacklogs(Trigger.new, Trigger.oldMap);
        } else if (Trigger.isDelete) {
            SprintItemServices.updateCurrentSprintOnBacklogsToMostRecentSprint(Trigger.old, Trigger.newMap);
        }
        BacklogItemServices.RUN_TRIGGER = true;

        if (Trigger.isUpdate) {
            SprintItemServices.updateStatusOnBacklogs(Trigger.new, Trigger.oldMap);
        }
    }
}
