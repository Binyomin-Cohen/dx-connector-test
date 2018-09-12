@isTest
private class Test_PopulateUnsupportedCustomSetting {
	static testMethod void testPopulateCustomSetting() {
    	// Assert cutom setting is empty
    	List<UnsupportedMetadataTypes__c> records = UnsupportedMetadataTypes__c.getAll().values();
    	System.assertEquals(0, records.size(), 'Custom Setting should be empty');
    	
    	PopulateUnsupportedMetadataCustomSetting c = new PopulateUnsupportedMetadataCustomSetting();
    	c.populateCustomSetting();
    	
    	List<UnsupportedMetadataTypes__c> actual = UnsupportedMetadataTypes__c.getAll().values();
        System.assertEquals(PopulateUnsupportedMetadataCustomSetting.unsupportedTypesList.size(), actual.size(), 'Expected number of Unsupported Metadata Types is not correct');
    }
}