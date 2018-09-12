public with sharing class CustomBacklogServices {

    public static final String SETTINGS_LABEL = 'CustomBacklogSort';
    public static final String MISSING_UNIVERSAL_BACKLOG_MESSAGE = 'The Universal Backlog cannot be found';
    public static final String UNIVERSAL_BACKLOG_ALREADY_EXISTS_MESSAGE = 'There is already a universal backlog record.';

    public static Custom_Backlog__c MASTER_BACKLOG_RECORD {
        get {
            if (MASTER_BACKLOG_RECORD == null) {
                Custom_Backlog__c masterBacklog = getUniversalBacklog();

                if (masterBacklog == null) {
                    throw new ALMException(MISSING_UNIVERSAL_BACKLOG_MESSAGE);
                } else {
                    MASTER_BACKLOG_RECORD = masterBacklog;
                }
            }

            return MASTER_BACKLOG_RECORD;
        }

        set;
    }

    public static List<Custom_Backlog__c> loadSortedCustomBacklogs(List<Custom_Backlog__c> customBacklogs) {
        if (customBacklogs.isEmpty()) {
            return customBacklogs;
        }

        CustomBacklogSort customBacklogSort = new CustomBacklogSort();
        try {
            State.retrieve(customBacklogSort);
		} catch (State.StateException se) {
			if (se.getMessage() != State.STATE_NOT_FOUND) {
				ALMLogServices.error(se, ALMLogServices.Application.BACKLOG_MANAGEMENT);
			}
            return customBacklogs;
        }

        List<String> sortedIdsState = customBacklogSort.getIds();

        if (sortedIdsState.isEmpty()) {
        	return customBacklogs;
        }

        List<Custom_Backlog__c> sortedCustomBacklogs = new List<Custom_Backlog__c>();
        Map<Id, Custom_Backlog__c> customBacklogMap = new Map<Id, Custom_Backlog__c>(customBacklogs);

        for ( String id : sortedIdsState ) {
        	if ( !String.isBlank(id) && customBacklogMap.containsKey(id) ) {
            	sortedCustomBacklogs.add(customBacklogMap.get(id));
                customBacklogMap.remove(id);
            }
        }

        Set<Id> sortedPluckedIds = Pluck.ids(sortedCustomBacklogs);
        for ( Id id : customBacklogMap.keySet() ) {
        	if ( !sortedPluckedIds.contains(id) ) {
            	sortedCustomBacklogs.add(customBacklogMap.get(id));
                sortedPluckedIds.add(id);
		    }
        }

        return sortedCustomBacklogs;
    }

    public static void updateCustomBacklogSortState(String customBacklogIds) {
    	if ( customBacklogIds == null ) {
    		return;
    	}

        List<String> ids = new List<String>();
        for (String customBacklogId : customBacklogIds.split(',')) {
            if (!String.isBlank(customBacklogId)) {
                ids.add(customBacklogId);
            }
        }
        CustomBacklogSort customBacklogSort = new CustomBacklogSort(ids);
        State.store(customBacklogSort);
    }

    public static void createUniversalBacklogIfMissing() {
        List<String>errors = new List<String>();
        if(getUniversalBacklog() == null) {
            Custom_Backlog__c universalBacklog = new Custom_Backlog__c(Name = Label.Backlog_Default_Name,
                                                                        Universal__c = true);

            try{
                insert universalBacklog;
            } catch (DMLException dex) {
                errors.add(dex.getMessage());
            }

            if (!errors.isEmpty()) {
                String body = String.join(errors, '\n');

                Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
                String[] mailTo = new String[] {'productdev@bluewolfgroup.com'};
                mail.setToAddresses(mailTo);
                mail.setSubject('Errors occurred during the universal backlog creation post install process');
                mail.setPlainTextBody(body);
                Messaging.sendEmail(new Messaging.SingleEmailMessage[] {mail});
            }
        }
    }

    public static List<Custom_Backlog__c> addErrorsToDuplicateUniversalBacklogs(List<Custom_Backlog__c> incomingBacklogs){
        List<Custom_Backlog__c> backlogsToReturn = new List<Custom_Backlog__c>();
        Custom_Backlog__c existingCustomBacklog = getUniversalBacklog();
        Boolean customBacklogAlreadyExists = existingCustomBacklog != null;

        for (Custom_Backlog__c incomingBacklog : incomingBacklogs) {
            if(incomingBacklog.Universal__c) {
                if(existingCustomBacklog != null && existingCustomBacklog.Id == incomingBacklog.id){
                    continue;
                }
                if(customBacklogAlreadyExists) {
                    incomingBacklog.addError(UNIVERSAL_BACKLOG_ALREADY_EXISTS_MESSAGE);
                } else {
                   customBacklogAlreadyExists = true;
                }
            }
            backlogsToReturn.add(incomingBacklog);
        }
        return backlogsToReturn;
    }

    public static Custom_Backlog__c getUniversalBacklog(){
        List<Custom_Backlog__c> masterBacklogs = [SELECT Id, Name
                                                    FROM Custom_Backlog__c
                                                    WHERE Universal__c = true
                                                    LIMIT 1];

        return masterBacklogs.isEmpty() ? null : masterBacklogs[0];
    }

    public class CustomBacklogSort implements State.IStateful {
        private List<String> customBacklogIds;

        public CustomBacklogSort() {
            this.customBacklogIds = new List<String>();
        }

        public CustomBacklogSort(List<String> customBacklogIds) {
            this.customBacklogIds = customBacklogIds;
        }

        public List<String> getIds() {
            for (Integer i = 0; i < customBacklogIds.size(); i++) {
                if( customBacklogIds[i] == BacklogManagementHomeController.MASTER_BACKLOG_IDENTIFIER ) {
                   customBacklogIds[i] = BacklogManagementHomeController.MASTER_BACKLOG_RECORD_ID;
                   break;
                }
            }
            return customBacklogIds;
        }

        public String getStateToken() {
            return SETTINGS_LABEL + '-' + UserInfo.getUserId();
        }

        public String serialize() {
            return JSON.serialize(customBacklogIds);
        }

        public void deserialize( String state ) {
            customBacklogIds = (List<String>) JSON.deserialize(state, List<String>.class);
        }
    }
}