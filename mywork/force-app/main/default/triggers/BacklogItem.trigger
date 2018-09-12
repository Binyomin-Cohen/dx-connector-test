trigger BacklogItem on Backlog__c (before insert, after insert, after update) {
    if (!BacklogItemServices.RUN_TRIGGER) return;

    if (Trigger.isBefore && Trigger.isInsert) {
        if (BacklogItemServices.RUN_TRIGGER_AUTO_PRIORITIZE) {
            BacklogItemServices.autoPrioritizeBacklogItems(Trigger.new);
        }
    }

    if (Trigger.isAfter) {
        SprintItemServices.RUN_TRIGGER = false;

        if (Trigger.isUpdate) {
            BacklogItemServices.updateStatusOnSprintItems(Trigger.new, Trigger.oldMap);
        }

        if (Trigger.isInsert || Trigger.isUpdate) {
            List<Backlog__c> filteredBacklogItems = 
                BacklogItemServices.filterBacklogItemsWithModifiedSprints(Trigger.oldMap, Trigger.new);

            SprintItemServices.updateSprintItemsFromBacklogItems(filteredBacklogItems);
        }

        SprintItemServices.RUN_TRIGGER = true;
    }
}