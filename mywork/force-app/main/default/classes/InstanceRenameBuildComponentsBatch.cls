public class InstanceRenameBuildComponentsBatch implements Database.Batchable<sObject> {
    
    private List<String> errors;
    private Id instanceId;
    private String oldInstanceName;
    private String newInstanceName;
    
    public InstanceRenameBuildComponentsBatch(Id instanceId, String oldName, String newName){
        this.errors = new List<String>();
        this.instanceId = instanceId;
        this.oldInstanceName = oldName;
        this.newInstanceName = newName;
        
    }
    
    public Database.QueryLocator start(Database.BatchableContext bc){
        return Database.getQueryLocator([select id, Component__c, Instance_Name__c from Build_Component__c
                                        Where Instance_Name__c = :this.oldInstanceName]);
    }
    
    public void execute(Database.BatchableContext BC, List<sObject> scope) {
        List<Build_Component__c> updatedBuildComponents = new List<Build_Component__c>();
        for (Build_Component__c bComponent : (List<Build_Component__c>) scope){
            bComponent.Instance_Name__c = this.newInstanceName;
            updatedBuildComponents.add(bComponent);
        }
        try {
            List<Database.SaveResult> srList = Database.update(updatedBuildComponents, false);
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
        try {
            InstanceModel model = InstanceServices.getInstanceModel(instanceId);
            model.clearRenameLock();
        } catch (Exception e) {
            errors.add(e.getMessage());
            ALMLogServices.error(e, ALMLogServices.Application.ADMIN_CONSOLE);
        }
    }
    
}