public class InstanceRenameComponentsBatch implements Database.Batchable<sObject> {
    
    private List<String> errors;
    private Id instanceId;
    private String oldInstanceName;
    private String newInstanceName;
    
    public InstanceRenameComponentsBatch(Id instanceId, String oldName, String newName){
        this.errors = new List<String>();
        this.instanceId = instanceId;
        this.oldInstanceName = oldName;
        this.newInstanceName = newName;
        
    }
    
    public Database.QueryLocator start(Database.BatchableContext bc){
        return Database.getQueryLocator([select Id, Source_Instances__c, Field_Modified_Data__c,
                                            (select id, Component__c, Instance_Name__c from Build_Components__r) 
                                        from Component__c 
                                        Where Source_Instances__c includes (:this.oldInstanceName)]);
    }
    
    public void execute(Database.BatchableContext BC, List<sObject> scope) {
        List<Component__c> updatedComponents = new List<Component__c>();
        for (Component__c comp : (List<Component__c>) scope){
            ComponentServices.renameInstanceName(comp, this.oldInstanceName, this.newInstanceName);
            updatedComponents.add(comp);
        }
        try {
            List<Database.SaveResult> srList = Database.update(updatedComponents, false);
            for (Database.SaveResult sr : srList){
                if (!sr.isSuccess()){
                    for (Database.Error err : sr.getErrors()){
                        errors.add(sr.getId() + ' : ' + err.getMessage());
                    }
                }
            }
        } catch (DMLException e){
            errors.add(e.getMessage());
            ALMLogServices.error(e, ALMLogServices.Application.ADMIN_CONSOLE);
        }
    }
    
    public void finish(Database.BatchableContext BC){
        if (!this.errors.isEmpty()){
            // send email 
        }
        Database.executeBatch(new InstanceRenameBuildComponentsBatch(instanceId, this.oldInstanceName, this.newInstanceName));
    }
    
}