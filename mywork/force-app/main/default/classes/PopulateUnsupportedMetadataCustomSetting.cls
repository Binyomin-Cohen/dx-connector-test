public with sharing class PopulateUnsupportedMetadataCustomSetting {
	Integer idx = 1;
	public static List<String> unsupportedTypesList = new List<String> {'Account Team',
															            'Activity Button Override',
																        'Analytic Setting',
																        'Auto-number on Customizable Standard Field',
																        'Campaign Influence',
																        'Case Contact Role',
																        'Case Feed Layout',
																        'Case Team Role',
																        'Console Layout',
																        'Currency Exchange Rate',
																        'Data Category Visibility Setting',
																        'Delegated Administration',
																        'Division',
																        'Field History Tracking – Currency and Owner Field',
																        'Fiscal Year',
																        'HTML Document and Attachment Setting',
																        'Label Rename',
																        'Lead Setting',
																        'Mail Merge Template',
																        'Mobile Administration',
																        'Mobile Users and Device',
																        'Offline Briefcase Configuration',
																        'Opportunity Big Deal Alert',
																        'Opportunity Update Reminder',
																        'Organization Wide Email Address',
																        'Partner Management',
																        'Predefined Case Team',
																        'Product Schedule Setup',
																        'Public and Resource Calendar',
																        'Quote Template',
																        'Salesforce to Salesforce',
																        'Search Setting',
																        'Self-Service Portal Font and Color',
																        'Self-Service Portal Setting',
																        'Self-Service Portal User',
																        'Self-Service Public Solution',
																        'Self-Service Web-to-Case',
																        'Sharing Organization Wide Default',
																        'Site.com',
																        'Social Account/Contact Setting',
																        'Solution Category',
																        'Solution Setting',
																        'Support Setting',
																        'Tab Rename',
																        'Tag Setting',
																        'Territory Assignment Rule',
																        'User Interface Setting',
																        'Web Links on Person Account Page Layout',
																        'Web-to-Lead'
																        };
		
	
    public void populateCustomSetting() {
    	List<UnsupportedMetadataTypes__c> customSetting = new List<UnsupportedMetadataTypes__c>();
    	
    	for (String typeName : unsupportedTypesList) {
    		customSetting.add(addType(typeName));
    	}
    	
        insert customSetting;
    }
    
    private UnsupportedMetadataTypes__c addType(String name) {
    	String fullName = name;
    	String truncatedName = name;
    	
    	if (name.length() >= 25) {
    		// Append an index to the end to ensure a unique truncated name
    		truncatedName = name.substring(0, 25) + idx;
    		idx++;
    	}
    	
    	UnsupportedMetadataTypes__c mdType = new UnsupportedMetadataTypes__c();
    	mdType.Name = truncatedName;
    	mdType.Name__c = fullName;
    	return mdType;
    } 
}