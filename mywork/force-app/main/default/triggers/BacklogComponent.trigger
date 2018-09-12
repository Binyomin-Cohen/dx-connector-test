trigger BacklogComponent on Backlog_Component__c (after delete) {
    if (Trigger.isAfter) {
        if (Trigger.isDelete) {
            // Clone read-only records for modification.
            Set<Backlog_Component__c> deletedBacklogComponents = new Set<Backlog_Component__c>();
            for (Backlog_Component__c backlogComponent : Trigger.old) {
                deletedBacklogComponents.add(backlogComponent.clone(true, true, true, true));
            }

            // Update profile data with deleted backlog components.
            BacklogComponentServices.removeDeletedBacklogComponentsFromProfileData(deletedBacklogComponents);
        }
    }
}