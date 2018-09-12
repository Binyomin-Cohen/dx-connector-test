public class SprintItemServices {

    public static Boolean RUN_TRIGGER = true;

    public static Map<Id, Id> getBacklogItemIdsWithLatestSprintIds(List<Sprint_Item__c> sItemList) {
        return BacklogItemServices.getBacklogItemIdsWithLatestSprintIds(Pluck.ids(SObjectServices.getFullyQualifiedName('Backlog__c'), sItemList));
    }

    public static void updateCurrentSprintOnBacklogsToMostRecentSprint(List<Sprint_Item__c> sItemList, Map<Id, Sprint_Item__c> oldMap) {
        List<Backlog__c> bklgsToUpdate = BacklogItemServices.populateCurrentSprintOnBacklogs(
            getBacklogItemIdsWithLatestSprintIds(
                SObjectServices.filterObjectsWithFieldUpdate(
                    sItemList,
                    oldMap,
                    Schema.Sprint_Item__c.Sprint__c
                )
            )
        );

        BacklogItemServices.updateBacklogs(bklgsToUpdate);
    }

    public static void updateCurrentSprintOnBacklogs(List<Sprint_Item__c> sItemList, Map<Id, Sprint_Item__c> oldMap) {
        List<Sprint_Item__c> updatedSprintItems = SObjectServices.filterObjectsWithFieldUpdate(
            sItemList,
            oldMap,
            Schema.Sprint_Item__c.Sprint__c
        );

        Map<Id, Backlog__c> backlogsToUpdate = new Map<Id, Backlog__c>();
        for (Sprint_Item__c sItem : updatedSprintItems) {
            backlogsToUpdate.put(sItem.Backlog__c, new Backlog__c(Id = sItem.Backlog__c, Current_Sprint__c = sItem.Sprint__c));
        }

        BacklogItemServices.updateBacklogs(backlogsToUpdate.values());
    }

    public static void updateStatusOnBacklogs(List<Sprint_Item__c> newList, Map<Id, Sprint_Item__c> oldMap) {
        Set<Id> sprintIds = new Set<Id>();
        for (Sprint_Item__c sprintItem : newList) {
            sprintIds.add(sprintItem.Sprint__c);
        }

        Map<Id, String> sprintIdToSprintStatus = new Map<Id, String>();
        for (Sprint__c sprint : [SELECT Status__c FROM Sprint__c WHERE Id IN :sprintIds]) {
            sprintIdToSprintStatus.put(sprint.Id, sprint.Status__c);
        }

        Set<String> backlogItemStatuses = new Set<String>(SObjectServices.getPicklistValues(Schema.SObjectType.Backlog__c.fields.Status__c));
        List<Sprint_Item__c> sprintItemsEligibleToUpdate = new List<Sprint_Item__c>();
        for (Sprint_Item__c newSprintItem : newList) {
            if ((sprintIdToSprintStatus.get(newSprintItem.Sprint__c) != SprintModel.COMPLETED_STATUS) && (backlogItemStatuses.contains(newSprintItem.Status__c))) {
                sprintItemsEligibleToUpdate.add(newSprintItem);
            }
        }

        List<Sprint_Item__c> sprintItemsWithChangedStatuses =
            SObjectServices.filterObjectsWithFieldUpdate(
                sprintItemsEligibleToUpdate,
                oldMap,
                Schema.Sprint_Item__c.Status__c
            );

        List<Backlog__c> backlogItemsToUpdate = new List<Backlog__c>();
        for (Sprint_Item__c sprintItem : sprintItemsWithChangedStatuses) {
            backlogItemsToUpdate.add(new Backlog__c(Id = sprintItem.Backlog__c, Status__c = sprintItem.Status__c));
        }
        BacklogItemServices.updateBacklogs(backlogItemsToUpdate);
    }

    /**
    * @throws ALMException, DMLException
    * @param sprintId - The ID of the sprint for which to create a new sprint item.
    * @param backlogId - The ID of the backlog item from which to create a new sprint item.
    * @return ID of the new sprint item on successful creation, null when no item is created, otherwise throws an exception.
    */
    public static String createSprintItem(String sprintId, String backlogId) {
        List<Backlog__c> backlogItems = new List<Backlog__c>{
            new Backlog__c(Id = backlogId, Current_Sprint__c = sprintId)
        };

        Map<Id, Id> backlogsToNewSprintItems = updateSprintItemsFromBacklogItems(backlogItems);

        return backlogsToNewSprintItems.get(backlogId);
    }

    /**
    * This method may create or delete sprint items, depending on the backlog items provided to it and the current state of the sprint items associated with them.
    * @throws ALMException, DMLException
    * @param backlogs - The backlog items from which to create a new sprint item. Backlog items with null sprint values will have existing non-incomplete sprint items deleted.
    * @return Map between the backlog item IDs and the sprint item IDs (null if no new sprint items were created), otherwise throws an exception.
    */
    public static Map<Id, Id> updateSprintItemsFromBacklogItems(List<Backlog__c> backlogs) {
        // The desired "backlog ID -> sprint" mapping.
        Map<Id, Id> backlogsToDesiredSprints = new Map<Id, Id>();
        // The "backlog ID -> backlog item" mapping.
        Map<Id, Backlog__c> backlogIdsToBacklogItems = new Map<Id, Backlog__c>();
        for (Backlog__c backlog : backlogs) {
            backlogsToDesiredSprints.put(backlog.Id, backlog.Current_Sprint__c);
            backlogIdsToBacklogItems.put(backlog.Id, backlog);
        }

        // Backlog IDs which have open unmodifiable sprint items.
        Set<Id> backlogsWithOpenUnmodifiableSprintItems = selectBacklogsWithOpenUnmodifiableSprintItems(backlogs);
        // The "backlog ID -> latest modifiable sprint item" mapping.
        Map<Id, Sprint_Item__c> backlogsToModifiableSprintItems = mapBacklogsToModifiableSprintItems(backlogs);
        // The "backlog ID -> status of desired sprint" mapping.
        Map<Id, String> backlogsToNewSprintStatus = mapBacklogsToSprintStatus(backlogs);
        // The "backlog ID -> all sprints containing backlogs" mapping.
        Map<Id, Set<Id>> backlogsToSprints = mapBacklogsToSprints(backlogs);

        // Check for existing not-incomplete sprint items that are tied to the respective backlog items.
        List<Sprint_Item__c> newSprintItems = new List<Sprint_Item__c>();
        List<Id> sprintItemIdsToDelete = new List<Id>();
        Map<Id, Id> backlogsToNewSprintItems = new Map<Id, Id>();

        for (Id backlogId : backlogsToDesiredSprints.keySet()) {

            // Grab the ID for the sprint of the existing modifiable sprint item for comparison to the proposed new sprint.
            Id existingSprintId = null;
            Sprint_Item__c existingSprintItem = backlogsToModifiableSprintItems.get(backlogId);
            if (existingSprintItem != null) {
                existingSprintId = existingSprintItem.Sprint__c;
            }

            Id newSprintId = backlogsToDesiredSprints.get(backlogId);
            String newSprintStatus = backlogsToNewSprintStatus.get(backlogId);
            Set<Id> sprintsWhereBacklogExists = backlogsToSprints.get(backlogId);

            if (newSprintId == null) {

                // If the item does not require a sprint item, skip it and potentially delete an existing sprint item.
                if (existingSprintId != null) {
                    // Delete the eligible existing sprint item.
                    sprintItemIdsToDelete.add(existingSprintItem.Id);
                }

                // The backlog item is not associated with a new sprint item because no sprint value exists on the record.
                backlogsToNewSprintItems.put(backlogId, null);

            } else if (newSprintStatus != null && newSprintStatus.equals(SprintModel.COMPLETED_STATUS)) {

                // No new sprint item has been created for this backlog item because the desired sprint is completed.
                backlogsToNewSprintItems.put(backlogId, null);
                // Add an error to the record.
                backlogIdsToBacklogItems.get(backlogId).addError(Label.Sprint_Item_Cannot_Add_To_Completed_Sprint);

            } else if (sprintsWhereBacklogExists != null && sprintsWhereBacklogExists.contains(newSprintId)) {

                // No new sprint item has been created for this backlog item because one already exists within the sprint.
                backlogsToNewSprintItems.put(backlogId, null);

            } else if (backlogsWithOpenUnmodifiableSprintItems.contains(backlogId)) {

                // The backlog item is not associated with a new sprint item because open unmodifiable sprint items exist.
                backlogsToNewSprintItems.put(backlogId, null);
                // Add an error to the record.
                backlogIdsToBacklogItems.get(backlogId).addError(Label.Sprint_Item_Open_Sprint_Item_Exists);

            } else {

                // Mark the existing sprint item to be deleted.
                if (existingSprintId != null) {
                    sprintItemIdsToDelete.add(backlogsToModifiableSprintItems.get(backlogId).Id);
                }

                // Create the desired new sprint item for the backlog item.
                newSprintItems.add(buildSprintItem(newSprintId, backlogId, SprintModel.NOT_STARTED_STATUS));

            }
        }

        // Update the sprint items.
        deleteSprintItems(sprintItemIdsToDelete);
        insert newSprintItems;

        // Create and return the final mapping of backlog items to latest sprint items.
        for (Sprint_Item__c sprintItem : newSprintItems) {
            backlogsToNewSprintItems.put(sprintItem.Backlog__c, sprintItem.Id);
        }
        return backlogsToNewSprintItems;
    }

    public static Sprint_Item__c buildSprintItem(Id sprintId, Id backlogId, String status) {
        return new Sprint_Item__c(
            Sprint__c = sprintId,
            Backlog__c = backlogId,
            Status__c = status
        );
    }

    /**
    * @throws DMLException
    * @param sprintItemId - The ID of the sprint item to delete.
    */
    public static void deleteSprintItem(String sprintItemId) {
        Sprint_Item__c sprintItem = new Sprint_Item__c(Id = sprintItemId);
        delete sprintItem;
    }

    /**
    * @throws DMLException
    * @param sprintItemIds - A list of IDs of the sprint items to delete.
    */
    public static void deleteSprintItems(List<String> sprintItemIds) {
        List<Sprint_Item__c> sprintItems = new List<Sprint_Item__c>();

        for (Id sprintItemId : sprintItemIds) {
            sprintItems.add(new Sprint_Item__c(Id = sprintItemId));
        }

        delete sprintItems;
    }

    /**
    * Selects backlog item IDs which have sprint item IDs which are not incomplete, but may not be modified (e.g. not yet marked as incomplete but live in completed sprints).
    */
    private static Set<Id> selectBacklogsWithOpenUnmodifiableSprintItems(List<Backlog__c> backlogs) {
        Set<Id> backlogsWithOpenUnmodifiableSprintItems = new Set<Id>();

        // Grab all of the latest not-incomplete sprint items corresponding to the backlog items.
        List<Sprint_Item__c> sprintItems = [
            SELECT Sprint__c, Backlog__c
            FROM Sprint_Item__c
            WHERE
                Backlog__c IN :backlogs AND
                Status__c != :SprintModel.INCOMPLETE_STATUS AND
                Sprint__r.Status__c = :SprintModel.COMPLETED_STATUS
            ORDER BY Sprint__r.Start_Date__c DESC
        ];

        // Map each backlog item to its latest not-incomplete sprint item.
        for (Sprint_Item__c sprintItem : sprintItems) {
            backlogsWithOpenUnmodifiableSprintItems.add(sprintItem.Backlog__c);
        }

        return backlogsWithOpenUnmodifiableSprintItems;
    }

    /**
    * Maps backlog item IDs to the sprint item with the most-recent start date which may be modified (does not belong to a completed sprint).
    */
    private static Map<Id, Sprint_Item__c> mapBacklogsToModifiableSprintItems(List<Backlog__c> backlogs) {
        Map<Id, Sprint_Item__c> backlogsToModifiableSprintItems = new Map<Id, Sprint_Item__c>();

        // Grab all of the latest not-incomplete sprint items corresponding to the backlog items.
        List<Sprint_Item__c> sprintItems = [
            SELECT Sprint__c, Backlog__c
            FROM Sprint_Item__c
            WHERE
                Backlog__c IN :backlogs AND
                Status__c != :SprintModel.INCOMPLETE_STATUS AND
                Sprint__r.Status__c != :SprintModel.COMPLETED_STATUS
            ORDER BY Sprint__r.Start_Date__c DESC
        ];

        // Map each backlog item to its latest not-incomplete sprint item.
        for (Sprint_Item__c sprintItem : sprintItems) {
            if (!backlogsToModifiableSprintItems.containsKey(sprintItem.Backlog__c)) {
                backlogsToModifiableSprintItems.put(sprintItem.Backlog__c, sprintItem);
            }
        }

        return backlogsToModifiableSprintItems;
    }

    /**
    * Maps backlog item IDs to the status of their associated sprints.
    */
    private static Map<Id, String> mapBacklogsToSprintStatus(List<Backlog__c> backlogs) {
        Map<Id, String> backlogsToSprintStatus = new Map<Id, String>();

        Set<Id> sprintIds = new Set<Id>();
        for (Backlog__c backlog : backlogs) {
            sprintIds.add(backlog.Current_Sprint__c);
        }

        // Grab all of the latest not-incomplete sprint items corresponding to the backlog items.
        Map<Id, Sprint__c> sprints = new Map<Id, Sprint__c>([
            SELECT Status__c
            FROM Sprint__c
            WHERE Id IN :sprintIds
        ]);

        // Map each backlog item to its latest not-incomplete sprint item.
        for (Backlog__c backlog : backlogs) {
            Sprint__c sprint = sprints.get(backlog.Current_Sprint__c);
            if (sprint != null) {
                backlogsToSprintStatus.put(backlog.Id, sprint.Status__c);
            }
        }

        return backlogsToSprintStatus;
    }

    /**
    * Maps backlog item IDs to a set of sprints which contain them.
    */
    private static Map<Id, Set<Id>> mapBacklogsToSprints(List<Backlog__c> backlogs) {
        Map<Id, Set<Id>> backlogsToSprints = new Map<Id, Set<Id>>();

        Set<Id> backlogIds = new Set<Id>();
        for (Backlog__c backlog : backlogs) {
            backlogIds.add(backlog.Id);
        }

        // Grab all of the sprints where each of the backlog items appear.
        List<Sprint_Item__c> sprintItems = [
            SELECT Backlog__c, Sprint__c
            FROM Sprint_Item__c
            WHERE Backlog__c IN :backlogIds
        ];

        // Map each backlog item to its latest not-incomplete sprint item.
        for (Sprint_Item__c sprintItem : sprintItems) {
            Set<Id> sprintIds = backlogsToSprints.get(sprintItem.Backlog__c);

            if (sprintIds == null) {
                sprintIds = new Set<Id>();
            }

            sprintIds.add(sprintItem.Sprint__c);
            backlogsToSprints.put(sprintItem.Backlog__c, sprintIds);
        }

        return backlogsToSprints;
    }
}
