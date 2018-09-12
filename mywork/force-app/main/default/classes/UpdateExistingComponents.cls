public class UpdateExistingComponents implements Database.Batchable<sObject>, Database.Stateful {
    public final String soql = 'Select Field_Modified_Data__c,Instance_Count__c FROM Component__c Where Instance_Count__c = 1 OR Instance_Count__c = null';
    public List<String> errors;
    
    public UpdateExistingComponents() {
    	errors = new List<String>();
    }
    
    public Database.Querylocator start(Database.BatchableContext bc) {
    	PmPostInstallHelper__c setting = PmPostInstallHelper__c.getOrgDefaults();
    	setting.Enable_Rule__c = false;
        upsert setting;
        
        return Database.getQueryLocator(soql);
    }
    
    public void execute(Database.BatchableContext BC, List<Component__c> scope) {
        List<Component__c> updates = new List<Component__c>();
        
        for (Component__c component : scope) {
            if (String.isBlank(component.Field_Modified_Data__c)) {
                component.Instance_Count__c = 0;
                updates.add(component);
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
    	// Set custom setting flag to activate the validation rule on component
    	PmPostInstallHelper__c setting = PmPostInstallHelper__c.getOrgDefaults();
    	setting.Enable_Rule__c = true;
    	upsert setting;
    	
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