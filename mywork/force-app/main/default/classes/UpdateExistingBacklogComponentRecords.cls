public class UpdateExistingBacklogComponentRecords implements Database.Batchable<sObject>, Database.Stateful {
	public final String query = 'Select Id, Source_Sandbox__c, Source_Instance__c from Backlog_Component__c Where Source_Instance__c = \''  + '\'';
	public Map<String, Id> sourceInstanceMap;
	public List<String> errors;
	
	public UpdateExistingBacklogComponentRecords() {
		sourceInstanceMap = new Map<String, Id>();
		errors = new List<String>();
	}
	
    public Database.Querylocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator(query);
    }
    
    public void execute(Database.BatchableContext BC, List<sObject> scope) {
    	List<sObject> updates = new List<sObject>();
    	
        for (sObject obj : scope) {
        	String instanceName = (String) obj.get('Source_Sandbox__c');
        	
        	if (!String.isBlank(instanceName)) {
	        	if (sourceInstanceMap.containsKey(instanceName)) {
	        		obj.put('Source_Instance__c', sourceInstanceMap.get(instanceName));	
	        	} else {
	        		// create new instnace record
	        		Instances__c rec = new Instances__c(Name=instanceName);
	        		Database.SaveResult result = Database.insert(rec);
	        		if (result.isSuccess()) {
	        			sourceInstanceMap.put(instanceName, result.getId());
	        			obj.put('Source_Instance__c', result.getId());	
	        		} else {
	        			for (Database.Error e : result.getErrors()) {
	        				errors.add(e.getMessage());
	        			}
	        		}
	        	}
	        	
	        	updates.add(obj);
        	}
        }
        	
    	Database.SaveResult[] updateResults = Database.update(updates, false);
    	
    	for (Database.SaveResult r : updateResults) {
    		if (!r.isSuccess()) {
    			for (Database.Error e : r.getErrors()) {
					errors.add(e.getMessage());
				}
    		}	
    	}
    }
    
    public void finish(Database.BatchableContext BC) {
    	
    	if (errors.size() > 0) {
    		String body = '';
    		for (String errorMsg : errors) {
    			body += errorMsg;
    			body += '\n';
    		}
    		
	    	Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
	    	String[] mailTo = new String[] {'productdev@bluewolfgroup.com'};
	    	mail.setToAddresses(mailTo);
	    	mail.setSubject('Errors occurred during the PM module batch job');
	    	mail.setPlainTextBody(body);
	    	Messaging.sendEmail(new Messaging.SingleEmailMessage[] {mail});
    	}
    }
}