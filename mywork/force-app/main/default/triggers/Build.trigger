trigger Build on Build__c (after update) {

	if (trigger.isAfter && trigger.isUpdate) {
		BuildServices.deployFinishedBuilds(trigger.oldMap, trigger.new);
	}
}