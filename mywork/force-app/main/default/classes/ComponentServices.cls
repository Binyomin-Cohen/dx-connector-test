public with sharing class ComponentServices {
    public static Boolean RUN_TRIGGER = true;
    public static final String APEX_ALM_NAME = 'Apex Class';
    public static final String FIELD_ALM_NAME = 'Field';
    public static final String LAYOUT_ALM_NAME = 'Layout';
    public static final String RECORD_TYPE_ALM_NAME = 'Record Type';
    public static final String OBJECT_ALM_NAME = 'Object';

    private static Map<Id, Instances__c> instanceMap {
        get {
            if (instanceMap == null) {
                instanceMap = new Map<Id, Instances__c>(InstanceServices.getAllInstances());
            }
            return instanceMap;
        }
        set;
    }

    /**
    *   Counts the number of environments that each component exists in, with
    *   the result being stored on the Component__c.Instance_Count__c field
    */
    public static void countInstances(List<Component__c> components)
    {
        for(Component__c component : components)
        {
            if (String.isBlank( component.Field_Modified_Data__c ))
            {
                component.Instance_Count__c = 0;
            }
            else
            {
                try
                {
                    List<FieldModifiedData> instanceData =
                        (List<FieldModifiedData>) JSON.deserialize(component.Field_Modified_Data__c, List<FieldModifiedData>.class);
                    component.Instance_Count__c = instanceData.size();
                }
                catch( JSONException je)
                {
                    System.debug( je );
                    component.Instance_Count__c = 1;
                }
            }
        }
    }

    public static void populateInstanceData(Component__c c) {
        setSourceInstance(c);
        createFieldModifiedData(c);
    }


    /**
    *  Sets the Field_Modified_Data__c field with JSON data if user creates or updates a component record.
    */
    public static void createFieldModifiedData(Component__c c) {
        Instances__c instance = instanceMap.get(c.Instance__c);

        if (instance != null) {
            List<FieldModifiedData> dataToSerialize = new List<FieldModifiedData>();
            List<FieldModifiedData> existingData;

            // Deserialize existing data
            if (!String.isEmpty(c.Field_Modified_Data__c)) {
                existingData = (List<FieldModifiedData>) JSON.deserialize(c.Field_Modified_Data__c, List<FieldModifiedData>.class);

                // Re add existing data to the serialized list
                for (FieldModifiedData fmd : existingData) {
                    dataToSerialize.add(fmd);
                }
            }

            // Add new instance only if it does not already exist in the field modify data
            if (!doesEnvironmentExist(instance.Name, existingData)) {
                FieldModifiedData instanceName = new FieldModifiedData(instance.Name);
                dataToSerialize.add(instanceName);
            }

            // Serialize and set the field
            String serializedData = Json.serialize(dataToSerialize);
            c.Field_Modified_Data__c = serializedData;
            c.Instance__c = null;
        }
    }

    public static String getComponentName(Component__c component) {
        if (component == null) {
            return '';
        } else {
            return (String.isBlank(component.Full_Name__c)) ? component.Name :  component.Full_Name__c;
        }
    }


    /**
    * Generates the key for the component of format "componentName|type|parentName".
    * Will return empty string if all of the input values are null or if componentName or type is null.
    * @param componentName   name of component
    * @param type            name of type
    * @param parentName      name of parent component
    * @return String key of format "componentName|type|parentName"
    */
    public static String createComponentKey(String componentName, String type, String parentName) {
        if ( String.isBlank(componentName) || String.isBlank(type) ) {
            return '';
        }
        return componentName + '|' + type + '|' + ( (String.isBlank(parentName)) ? '' : parentName );
    }

    /**
    * Appends the instance to the components Source Instances field if it hasn't already been appended
    */
    private static void setSourceInstance(Component__c component) {
        if (!instanceMap.containsKey(component.Instance__c)) return;
        String instance = instanceMap.get(component.Instance__c).Name;

        if (String.isBlank(component.Source_Instances__c)) {
            component.Source_Instances__c = instance;
        } else {
            Set<String> instances = new Set<String>();
            instances.addAll(component.Source_Instances__c.split(';'));
            if (!instances.contains(instance)) {
                component.Source_Instances__c += ';' + instance;
            }
        }
    }

    /**
    * Updates the instance name on the component's Source Instances and FieldModifiedData fields
    */
    public static void renameInstanceName(Component__c component, String oldName, String newName) {

        if (String.isBlank(component.Source_Instances__c)) {
            component.Source_Instances__c = newName;
        } else {
            Set<String> instances = new Set<String>(component.Source_Instances__c.split(';'));
            instances.remove(oldName);
            instances.add(newName);
            component.Source_Instances__c = String.join(new List<String>(instances), ';');
        }
        if (String.isBlank(component.Field_Modified_Data__c)){
            component.Field_Modified_Data__c = Json.serialize(new List<FieldModifiedData>{new FieldModifiedData(newName)});
        } else {
            List<FieldModifiedData> existingData = (List<FieldModifiedData>) JSON.deserialize(component.Field_Modified_Data__c, List<FieldModifiedData>.class);
            for (FieldModifiedData fmd : existingData){
                if (fmd.environmentName == null || fmd.environmentName.equalsIgnoreCase(oldName)){
                    fmd.environmentName = newName;
                }
            }
            String serializedData = Json.serialize(existingData);
            component.Field_Modified_Data__c = serializedData;
        }
    }

    public static void setKey(Component__c component) {
        String fullName = getComponentName(component);
        String type = '|' + component.Type__c + '|';
        String parent = (component.Parent_Component__c == null) ? '' : component.Parent_Component__c;

        String rawKey = fullName + type + parent;
        Blob keyHash = Crypto.generateDigest('SHA1',Blob.valueOf(rawKey));
        String keyEncoded = EncodingUtil.convertToHex(keyHash);

        component.Key__c = keyEncoded;
    }

    /**
    * Checks to see if an instance name already exists in the Field_Modified_Data__c
    */
    private static Boolean doesEnvironmentExist(String environmentName, List<FieldModifiedData> existingData) {
        Boolean found = false;

        if (existingData == null) {
            return found;
        }

        for (FieldModifiedData o : existingData) {
            String existingName = o.environmentName;

            if (existingName != null && existingName.equalsIgnoreCase(environmentName)) {
                found = true;
                break;
            }
        }

        return found;
    }

    /**
    * Get LastModifiedBy username for each instance on a component's Field_Modified_Data
    */
    public static Set<String> getLastModifiedByUsernames(Component__c c) {
        Set<String> lastModifiedByUsernames = new Set<String>();
        List<FieldModifiedData> existingData;

        if (!String.isEmpty(c.Field_Modified_Data__c)) {
            try {
                existingData = (List<FieldModifiedData>) JSON.deserialize(c.Field_Modified_Data__c, List<FieldModifiedData>.class);
            } catch (JSONException je) {
                System.debug(je.getMessage());
                return new Set<String>();
            }

            for (FieldModifiedData fmd : existingData) {
                if (!String.isEmpty(fmd.lastModifiedByName)) {
                        lastModifiedByUsernames.add(fmd.lastModifiedByName);
                }
            }
        }
        return lastModifiedByUsernames;
    }

    /**
    * Populates Last Modified users and returns set of all users from modified components
    * @param modifiedComponents	List of modified components
    * @return Set<String> The Set of all users from modified components
    */
    public static Set<String> populateLastModifiedUsers(List<Component__c> modifiedComponents) {

        Set<String> modifiedComponentUsers = new Set<String>();
        for (Component__c component : modifiedComponents) {
            Set<String> newUsers = getLastModifiedByUsernames(component);
            modifiedComponentUsers.addAll(newUsers);
            component.Last_Modified_Users__c = String.join(new List<String>(newUsers), ';');
        }

        return modifiedComponentUsers;
    }

    /**
    * Removes the deleted instances from the Source_Instances__c multi select picklist
    * @param component	Component from which we will remove the deleted instances names
    * @param deletedInstanceNames	Set<String> of all deleted instances names
    * @return String the updated source instances picklist
    */
    public static String removeDeletedInstancesFromSourceInstancesField( Component__c component, Set<String> deletedInstancesNames ) {
        String updatedSourceInstances = component.Source_Instances__c;

        if(String.IsNotBlank(updatedSourceInstances)) {
            Set<String> instanceNames = new Set<String> (updatedSourceInstances.split(';'));
            if( instanceNames.removeAll(deletedInstancesNames) ) {
               updatedSourceInstances = String.join(new List<String>(instanceNames),';');
            }
        }
        return updatedSourceInstances;
    }

    /**
    * Schedules the source instance cleaner  to run if it not already running
    */
    public static void scheduleSourceInstanceCleaner() {
        Integer minutesFromNow = 1;
        String cronExpression = ApplicationResultCleanerServices.buildCronExpressionFromMinutesInTheFuture(minutesFromNow);
        String cleanerName = ComponentSourceInstanceCleaner.SOURCE_INSTANCE_CLEANER_NAME;
        String cleanerClassName = 'ComponentSourceInstanceCleaner';

        if (!ApplicationResultCleanerServices.isCleanerRunning(cleanerClassName, cleanerName)) {
            System.schedule(cleanerName, cronExpression, new ComponentSourceInstanceCleaner());
        }
    }
}