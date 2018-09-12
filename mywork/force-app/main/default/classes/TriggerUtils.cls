public class TriggerUtils {
	public static List<sObject> filterUpdatesByUpdatedField(
			List<sObject> newRecords, Map<Id, sObject> oldMap, sObjectField field){

		List<sObject> filteredUpdates = new List<sObject>();
		for(sObject newRecord: newRecords){
			if( newRecord.get(field) != ((sObject)oldMap.get(newRecord.Id)).get(field)) {
				filteredUpdates.add(newRecord);
			}
		}
		return filteredUpdates;
	}
}