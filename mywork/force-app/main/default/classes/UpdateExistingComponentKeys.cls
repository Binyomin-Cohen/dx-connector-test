public class UpdateExistingComponentKeys implements Database.Batchable<sObject>, Database.Stateful {
    public final String soql = 'Select Id, Name, Full_Name__c, Type__c, Parent_Component__c, Key__c FROM Component__c Where Key__c = \'\'';
    public List<String> errors;
    
    public UpdateExistingComponentKeys() {
      errors = new List<String>();
    }
    
    public Database.Querylocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator(soql);
    }
    
    public void execute(Database.BatchableContext BC, List<Component__c> scope) {
        List<Component__c> updates = new List<Component__c>();
        
        for (Component__c component : scope) {
            updates.add(component);
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
            
            ALMLogServices.error(new ALMException(body), ALMLogServices.Application.PM_POST_INSTALL_SCRIPT);
        }
    }
}