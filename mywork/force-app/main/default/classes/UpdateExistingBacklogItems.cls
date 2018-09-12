public class UpdateExistingBacklogItems implements Database.Batchable<sObject>, Database.Stateful {
    
    private List<String> errorList;
    
    public UpdateExistingBacklogItems(){
        errorList = new List<String>();
    }
    
    public Database.Querylocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator([Select Id From Backlog__c]);
    }
    
    public void execute(Database.BatchableContext BC, List<Backlog__c> scope) {
        BacklogItemServices.RUN_TRIGGER = false;
        
        errorList.addAll(
            BacklogItemServices.updateBacklogs(
                BacklogItemServices.populateCurrentSprintOnBacklogs(
                    BacklogItemServices.getBacklogItemIdsWithLatestSprintIds(Pluck.ids(scope))
                )
            )
        );
    }
    
    public void finish(Database.BatchableContext BC) {
        if (errorList.size() > 0) {
            String body = '';
            for (String errorMsg : errorList) {
                body += errorMsg;
                body += '\n';
            }
            
            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            String[] mailTo = new String[] {'productdev@bluewolfgroup.com'};
            mail.setToAddresses(mailTo);
            mail.setSubject('Errors occurred - PM module Update Existing Backlog Items batch job');
            mail.setPlainTextBody(body);
            Messaging.sendEmail(new Messaging.SingleEmailMessage[] {mail});
        }
    }
}