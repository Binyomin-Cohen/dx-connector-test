trigger Component on Component__c (before insert, before update)
{
    if (!ComponentServices.RUN_TRIGGER) {
        return;
    }

    List<String> errors = new List<String>();

    if ( trigger.isInsert )
    {
        for (Component__c component : System.Trigger.new) {
            ComponentServices.populateInstanceData(component);
            ComponentServices.setKey(component);
        }

        // set Last_Modified_Users__c and insert new Component User Settings
        List<Component__c> modifiedComponents = System.Trigger.new;
        try {
            Set<String> users = ComponentServices.populateLastModifiedUsers(modifiedComponents);
            ALMSettingsServices.bulkInsertNewComponentUserSettings(users);
        } catch (Exception e) {
            ALMLogServices.error(e, ALMLogServices.Application.SCAN);
        }

        ComponentServices.countInstances(trigger.new);
    }
    else if ( trigger.isUpdate )
    {
        List<Component__c> componentsToUpdate = new List<Component__c>();

        for(Component__c component : trigger.new)
        {
            ComponentServices.populateInstanceData(component);
            ComponentServices.setKey(component);

            Component__c oldComponent = trigger.oldMap.get(component.Id);
            if ( component.Field_Modified_Data__c != oldComponent.Field_Modified_Data__c )
            {
                componentsToUpdate.add( component );
            }
        }

        // set Last_Modified_Users__c and insert new Component User Settings
        try {
            Set<String> users = ComponentServices.populateLastModifiedUsers(componentsToUpdate);
            ALMSettingsServices.bulkInsertNewComponentUserSettings(users);
        } catch (Exception e) {
            ALMLogServices.error(e, ALMLogServices.Application.SCAN);
        }

        ComponentServices.countInstances( componentsToUpdate );
    }
}