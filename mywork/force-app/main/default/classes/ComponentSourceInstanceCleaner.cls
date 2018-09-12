public with sharing class ComponentSourceInstanceCleaner implements Database.Batchable<SObject>, Database.Stateful, Schedulable{
    public List<String> errors;
    public Set<String> deletedInstanceNames;
    public static String SOURCE_INSTANCE_CLEANER_NAME = 'Component Source Instance Field Cleaner';

    public ComponentSourceInstanceCleaner() {
        errors = new List<String>();
        deletedInstanceNames = InstanceServices.getDeletedInstanceNames();
    }

    public database.querylocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator([SELECT Id, Source_Instances__c FROM Component__c]);
    }

    public void execute(Database.BatchableContext bc, Sobject[] scope) {
        List<Component__c> componentsToUpdate = new List<Component__c>();

        for(Component__c component : (List<Component__c>) scope) {
            String updatedSourceInstances = ComponentServices.removeDeletedInstancesFromSourceInstancesField(component, deletedInstanceNames);
            if (component.Source_Instances__c != updatedSourceInstances) {
                component.Source_Instances__c = updatedSourceInstances;
                componentsToUpdate.add(component);
            }
        }

        if(!componentsToUpdate.isEmpty()) {
            try {
                List<Database.SaveResult> srList = Database.update(componentsToUpdate, false);
                for (Database.SaveResult sr : srList){
                    if (!sr.isSuccess()){
                        for (Database.Error err : sr.getErrors()){
                            errors.add(sr.getId() + ' : ' + err.getMessage());
                        }
                    }
                }
            } catch (DMLException e){
                errors.add(e.getMessage());
                ALMLogServices.error(e, ALMLogServices.Application.SCAN);
            }
        }
    }

    public void finish(Database.BatchableContext bc) {
        if (!errors.isEmpty()) {
            String body = String.join(errors, '\n');

            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            String[] mailTo = new String[] {'productdev@bluewolfgroup.com'};
            mail.setToAddresses(mailTo);
            mail.setSubject('Errors occurred during the '+SOURCE_INSTANCE_CLEANER_NAME+' process');
            mail.setPlainTextBody(body);
            Messaging.sendEmail(new Messaging.SingleEmailMessage[] {mail});
        }
    }

    public void execute(SchedulableContext context) {
        ComponentSourceInstanceCleaner cleanerToShedule = new ComponentSourceInstanceCleaner();
        Database.executeBatch( cleanerToShedule );
        System.abortJob(context.getTriggerId());
    }
}
