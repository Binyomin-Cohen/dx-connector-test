trigger VCRepo on VC_Repository__c (before insert, before update) {

	/*

		Current code does not allow edge case (that should be allowed) for example record names
		 got updated from a,b,c,d,e to a,b,c,e,d .  The fix could be as follows

		-  make a validateDuplicates(List existingRecords, List newRecords){
		   * make a set out of the existing records names
		   * iterate through new ones and try to add each to set - if false
		     -- add error
		     -- add it to duplicates list

	    -  for insert: the existing records are all the records in the db (their names) and new records
	     are trigger.new (names)

	     - for update:
	       * find all records whose names are being changed - these are the new records
	       * query existing records that are not in the above record ids, these are the existing ones
	*/

	if (Trigger.isBefore && (Trigger.isInsert || Trigger.isUpdate  ) ){
		List<VC_Repository__c> recordsToValidate = new List<VC_Repository__c>();
		if(Trigger.isInsert){
			recordsToValidate = Trigger.new;
		}
		else if(Trigger.isUpdate){
			recordsToValidate = TriggerUtils.filterUpdatesByUpdatedField(Trigger.new,Trigger.oldMap, VC_Repository__c.Name);
		}
		VCServices.validateRepoNamesForDuplicate(recordsToValidate);
	}

}