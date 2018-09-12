trigger InstancesTrigger on Instances__c (after update) {
    InstanceServices.scheduleComponentCleaningForDeletedInstances(Trigger.oldMap, Trigger.new);
}