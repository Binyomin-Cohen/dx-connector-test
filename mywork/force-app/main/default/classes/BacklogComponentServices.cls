public with sharing class BacklogComponentServices {
    /**
    * Updates profile permission data on a set of backlog components related to a given set of other backlog
    * components to be deleted. Profile backlog components are updated at this time.
    * @param deletedBacklogComponents - A set of backlog components that have been deleted.
    * @return Database.SaveResult - The results of updating profile backlog components.
    */
    public static Map<Id, Backlog_Component__c> removeDeletedBacklogComponentsFromProfileData(Set<Backlog_Component__c> deletedBacklogComponents) {
        return removeDeletedBacklogComponentsFromProfileData(deletedBacklogComponents, true);
    }

    /**
    * Updates profile permission data on a set of backlog components related to a given set of other backlog
    * components to be deleted. Profile backlog components are not updated at this time, by default.
    * @param deletedBacklogComponents - A set of backlog components that have been deleted.
    * @param updateProfiles - A flag that determines whether or not profile backlog components are updated
    * or simply returned.
    * @return Database.SaveResult - The results of updating profile backlog components.
    */
    public static Map<Id, Backlog_Component__c> removeDeletedBacklogComponentsFromProfileData(Set<Backlog_Component__c> deletedBacklogComponents, Boolean updateProfiles) {
        // Grab all backlog components related to profiles.
        Set<Backlog_Component__c> profileBacklogComponents = filterProfileBacklogComponents(deletedBacklogComponents);

        // If there are no profile-related backlog components, return.
        if (profileBacklogComponents.isEmpty()) {
            return null;
        }

        // Map backlog IDs to their associated manifest records.
        Map<Id, List<AssemblerManifestRecord>> backlogIdsToManifestRecords = 
            mapBacklogIdsToManifestRecords(profileBacklogComponents);

        // Map backlog IDs to their associated permissions maps.
        Map<Id, Map<String, Set<String>>> backlogIdToPermissionsMap = new Map<Id, Map<String, Set<String>>>();
        for (Id backlogId : backlogIdsToManifestRecords.keySet()) {
            backlogIdToPermissionsMap.put(
                backlogId, 
                ProfileServices.filterComponents(backlogIdsToManifestRecords.get(backlogId))
            );
        }

        // Grab all profile backlog components affected by the deletion, sorted by backlog item.
        List<Backlog__c> relevantBacklogItems = [
            SELECT Id, (
                SELECT Id, Source_Sandbox__c, Source_Instance__r.Name, Backlog__r.Name, Backlog__r.Status__c, 
                       Component__r.Name, Component__r.Full_Name__c, Component__r.Type__c, Component__r.Parent_Component__r.Name, Notes__c, 
                       Profile_Permission__c, Profile_Data_1__c, Profile_Data_2__c, Include_Entire_Profile__c, Profile__c, Profile__r.Name, Profile__r.Full_Name__c
                FROM SCBridge__r
                WHERE (Profile_Permission__c = true OR Component__r.Type__c = 'Profile')) 
            FROM Backlog__c 
            WHERE Id IN :backlogIdsToManifestRecords.keySet()
        ];

        // Remove permissions from each backlog component, on each backlog item.
        List<Backlog_Component__c> updatedProfileComponents = new List<Backlog_Component__c>();
        for (Backlog__c backlogItem : relevantBacklogItems) {
            for (Backlog_Component__c backlogComponent : backlogItem.SCBridge__r) {
                // Remove the permissions.
                ProfilePermissions profilePermissionsData = ProfilePermissions.valueOf(backlogComponent);
                profilePermissionsData.removePermissions(backlogIdToPermissionsMap.get(backlogItem.Id));
                ProfilePermissions.setProfilePermissionsData(backlogComponent, JSON.serialize(profilePermissionsData));

                // Add the profile backlog component to the list to be updated.
                updatedProfileComponents.add(backlogComponent);
            }
        }

        // Update the altered permissions on the profile backlog components.
        if (updateProfiles) {
            try {
                update updatedProfileComponents;
            } catch (DMLException de) {
                for (Integer i = 0; i < de.getNumDml(); ++i) {
                    updatedProfileComponents[de.getDmlIndex(i)].addError(de.getDmlMessage(i));
                }
                ALMLogServices.error(de, ALMLogServices.Application.COMPONENT_DOCUMENTATION);
            }
        }

        // Map final updated profile backlog component IDs to their associated records.
        Map<Id, Backlog_Component__c> updatedProfileComponentIdToRecord = new Map<Id, Backlog_Component__c>(updatedProfileComponents);

        return updatedProfileComponentIdToRecord;
    }

    /**
    * Filters a given set of backlog components by relevance to profiles.
    * @param backlogComponentsToFilter - A set of backlog components to filter for relevance to profiles.
    * @return - A set of backlog components relevant to profiles.
    */
    private static Set<Backlog_Component__c> filterProfileBacklogComponents(Set<Backlog_Component__c> backlogComponentsToFilter) {
        // Collect all related component IDs.
        Set<Id> componentIds = new Set<Id>();
        for (Backlog_Component__c backlogComponent : backlogComponentsToFilter) {
            componentIds.add(backlogComponent.Component__c);
        }

        // Map IDs of components of types relevant to profiles to their component records.
        Map<Id, Component__c> profileComponentIdsToComponents = new Map<Id, Component__c>();
        for (Component__c component : [SELECT Name, Full_Name__c, Type__c, Parent_Component__r.Name, Parent_Component__r.Full_Name__c FROM Component__c WHERE Id IN :componentIds]) {
            if (ProfileServices.COMPONENT_TYPE_TO_CATEGORY.containsKey(component.Type__c)) {
                profileComponentIdsToComponents.put(component.Id, component);
            }
        }

        // Collect all of the backlog components that are relevant to profiles.
        Set<Backlog_Component__c> profileBacklogComponents = new Set<Backlog_Component__c>();
        for (Backlog_Component__c backlogComponent : backlogComponentsToFilter) {
            if (profileComponentIdsToComponents.containsKey(backlogComponent.Component__c)) {
                backlogComponent.Component__r = profileComponentIdsToComponents.get(backlogComponent.Component__c);
                profileBacklogComponents.add(backlogComponent);
            }
        }

        return profileBacklogComponents;
    }

    /**
    * Maps backlog item IDs to lists of relevant manifest records.
    * @param - profileBacklogComponents - A set of backlog components to create "backlog ID => list of manifest records" associations from.
    * @return - A map associating backlog IDs with lists of manifest records.
    */
    private static Map<Id, List<AssemblerManifestRecord>> mapBacklogIdsToManifestRecords(Set<Backlog_Component__c> profileBacklogComponents) {
        Map<Id, List<AssemblerManifestRecord>> backlogIdsToManifestRecords = new Map<Id, List<AssemblerManifestRecord>>();
        for (Backlog_Component__c backlogComponent : profileBacklogComponents) {
            if (backlogIdsToManifestRecords.get(backlogComponent.Backlog__c) == null) {
                backlogIdsToManifestRecords.put(backlogComponent.Backlog__c, new List<AssemblerManifestRecord>());
            }
            backlogIdsToManifestRecords.get(backlogComponent.Backlog__c).add(new AssemblerManifestRecord(backlogComponent));
        }

        return backlogIdsToManifestRecords;
    }
}