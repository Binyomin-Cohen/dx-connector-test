public with sharing class InstanceServices {
    public static final Integer INSTANCE_NAME_MAX_LENGTH = 40;
    public static final Integer INSTANCE_NAME_MIN_LENGTH = 1;

    public static final String ERROR_INSTANCE_NAME_LENGTH = ' Instance name must be at least ' + String.valueOf(INSTANCE_NAME_MIN_LENGTH) + ' and at most ' + String.valueOf(INSTANCE_NAME_MAX_LENGTH) + ' characters long.';
    public static final String ERROR_INSTANCE_NAME_SPECIAL_CHARS = ' Instance names must be alphanumerics only.';
    public static final String ERROR_INSTANCE_TYPE = ' Instance type must be specified.';
    public static final String ERROR_INSTANCE_NAME_UNIQUE = ' Instance name must be unique.';

    public static final String LIGHTNING_DOMAIN_SUFFIX ='lightning.force.com';
    public static final String VF_DOMAIN_SUFFIX ='visual.force.com';

    public static List<String> instanceTypes;

    public static Instances__c almInstance {
        get {
            if (isAlmInstanceLoaded != true) {
                isAlmInstanceLoaded = true;
                List<Instances__c> instances = [
                    SELECT Id, Name, Custom_Domain__c, Type__c, Rename_Lock_Expiration_Time__c
                     FROM Instances__c
                     WHERE Is_ALM_Instance__c = true
                     LIMIT 1
                ];
                if (!instances.isEmpty()) {
                    almInstance = instances[0];
                }
            }
            return almInstance;
        }
        private set;
    }

    private static Boolean isAlmInstanceLoaded;

    public static List<Instances__c> getAllInstances() {
        return [SELECT Id, Name, Custom_Domain__c, Type__c, Rename_Lock_Expiration_Time__c FROM Instances__c WHERE Is_Deleted__c=false ORDER BY Name ASC];
    }

    public static Instances__c getInstance(String id) {
        List<Instances__c> instances = [SELECT Id, Name, Custom_Domain__c, Type__c, Rename_Lock_Expiration_Time__c FROM Instances__c WHERE Id = :id];
        if (instances.isEmpty()) {
            return null;
        } else {
            return instances[0];
        }
    }

    public static InstanceModel getInstanceModel(String instanceId) {
        Instances__c instance = getInstance(instanceId);
        return (instance == null) ? null : new InstanceModel(instance);
    }

    public static InstanceModel getInstanceByName(String name) {
        List<Instances__c> instances = [SELECT Id, Name, Custom_Domain__c, Type__c, Rename_Lock_Expiration_Time__c
                                        FROM Instances__c
                                        WHERE Name = :name];
        if (instances.isEmpty()) {
            return null;
        } else {
            return new InstanceModel(instances[0]);
        }
    }

    public static String getLoginEndpoint(Instances__c instance) {
        String serverURL;
        if (!String.isEmpty(instance.Custom_Domain__c)) {
            String customDomain = instance.Custom_Domain__c;
            serverURL = customDomain.startsWith('https') ? customDomain : 'https://' + customDomain;
        } else if (instance.Type__c == 'Sandbox') {
            serverURL = 'https://test.salesforce.com';
        } else {
            serverURL = 'https://login.salesforce.com';
        }
        return serverURL;
    }


    /**
    * @description Given a url from either a visualforce or lightning page, returns the visual force domain
    * @param url    a url from a visualforce or lightning context
    * @return the org visualforce domain
    */
    public static String getVisualforceDomain(String url) {
        URL currentURL = new URL(url);
        String currentDomain = currentURL.getProtocol() + '://' + currentURL.getHost();
        if (currentDomain.contains(VF_DOMAIN_SUFFIX)) {
            return currentDomain;
        } else {
            currentDomain = currentDomain.replace(LIGHTNING_DOMAIN_SUFFIX, VF_DOMAIN_SUFFIX);
        }
        return currentDomain;
    }


    public static List<String> getInstanceTypes() {
        if (instanceTypes == null) {
            instanceTypes = new List<String>();
            List<Schema.PicklistEntry> entries = Instances__c.Type__c.getDescribe().getPicklistValues();
            for (Schema.PicklistEntry entry : entries) {
                instanceTypes.add(entry.getLabel());
            }
        }

        return instanceTypes;
    }

    public static Boolean updateInstance(String id, String instanceType, String customDomain) {
        Instances__c instance = new Instances__c();
        instance.Id = id;
        instance.Type__c = instanceType;
        instance.Custom_Domain__c = customDomain;

        try {
            update instance;
            return true;
        } catch (DMLException de) {
            System.debug(de.getMessage());
            throw new ALMException(de.getMessage());
        }
    }

    /**
    * @throws ALMException
    * @param name - The name of the new instance to be added.
    * @param type - The type of the new instance to be added.
    * @return Boolean true on a successful insertion, otherwise throws an ALMException.
    */
    public static Boolean addNewInstance(InstanceModel model) {
        String name = model.record.Name;
        String restrictRegex = '[^A-Za-z0-9-_ ]';
        String scrubbedInstanceName = name.replaceAll(restrictRegex, '');
        // Check on name length.
        if(name.length() < INSTANCE_NAME_MIN_LENGTH || INSTANCE_NAME_MAX_LENGTH < name.length()) {
            throw new ALMException(System.Label.Instance_Add_Error + ERROR_INSTANCE_NAME_LENGTH);
        }

        if(name != scrubbedInstanceName) {
            throw new ALMException(System.Label.Instance_Add_Error + ERROR_INSTANCE_NAME_SPECIAL_CHARS);
        }

        // Check to ensure name uniqueness.
        Instances__c instanceFound = checkInstanceNameUniqueness(name);
        if(instanceFound != null && instanceFound.Is_Deleted__c == false) {
            throw new ALMException(System.Label.Instance_Add_Error + ERROR_INSTANCE_NAME_UNIQUE);
        }

        // Attempt to insert the new instance.
        try {
            insert model.record;
            return true;
        } catch(DMLException e) {
            throw new ALMException(System.Label.Instance_Add_Error + e.getMessage());
        }
    }

    /**
    * @param instanceName - String that represents the name of the instance being checked for duplicates
    * @return An instance record, if one is found, that is the existing instance.
    */
    public static Instances__c checkInstanceNameUniqueness(String instanceName) {
        Instances__c instanceFound;
        List<Instances__c> instancesFound = [SELECT Name, Is_Deleted__c FROM Instances__c WHERE Name=:instanceName LIMIT 1];
        if(!instancesFound.isEmpty()) {
           instanceFound = instancesFound[0];
        }
        return instanceFound;
    }

    /**
    * @param instanceToUndelete A record that represents the name of the instance to undelete
    */
    public static void undeleteInstance(Instances__c instanceToUndelete) {
        try{
            instanceToUndelete.Is_Deleted__c = false;
            update instanceToUndelete;
        } catch (Exception ex) {
            throw new ALMException(System.Label.Instance_Undelete_Error + ex.getMessage());
        }
    }

    /**
    * @param instanceIds - A list of instance IDs with which to associate scan results.
    * @return A map associating the given instance IDs with their corresponding scan results.
    */
    public static Map<String, InstanceModel.ScanResult> fetchScanResult(List<String> instanceIds) {
        return ALMApplicationResultServices.getLatestAlmApplicationResult(instanceIds, ALMJobServices.ToolType.SCAN);
    }

    /**
    * @param instanceId - The ID of the instance to be soft-deleted.
    * @return A boolean indicating success (true) or failure (false).
    */
    public static Boolean softDeleteInstance(Id instanceId) {
        List<Instances__c> instances = [SELECT Id, Is_Deleted__c FROM Instances__c WHERE Id=:instanceId LIMIT 1];
        return (instances.isEmpty() ? false : softDeleteInstance(instances[0]));
    }

    /**
    * @param instance - The instance to be soft-deleted.
    * @return A boolean indicating success (true) or failure (false).
    * @throws DMLException
    */
    public static Boolean softDeleteInstance(Instances__c instance) {
        if (instance == null) {
            return false;
        }

        instance.Is_Deleted__c = true;
        update instance;

        return true;
    }

    public static Boolean updateInstanceName(Instances__c instance, String newName) {
        List<Instances__c> existingInstances = [SELECT Name FROM Instances__c Where Name=:newName LIMIT 1];

        if (existingInstances.size() == 1) {
            throw new ALMException(ERROR_INSTANCE_NAME_UNIQUE);
        }

        try {
            instance.Name = newName;
            update instance;
            return true;
        } catch (DMLException e) {
          ALMLogServices.error(e, ALMLogServices.Application.ADMIN_CONSOLE);
          return false;
        }
    }

    public static Map<Id, ALMApplicationResultServices.InstanceWithLatestAndSuccessfulRunTime> populateCacheWithInstanceRunTimes(List<ALM_Application_Result__c> appResults) {
        BluewolfDevUtils sortingUtil = new BluewolfDevUtils();

        ALMApplicationResultServices.ResultState storedState = ALMApplicationResultServices.loadPageState();
        Map<Id, ALMApplicationResultServices.InstanceWithLatestAndSuccessfulRunTime> storedInstanceToRunTimes = storedState.getInstanceTimes();
        if (storedInstanceToRunTimes != null) {
            for (ALM_Application_Result__c result : (List<ALM_Application_Result__c>) sortingUtil.standardSortBy(appResults, SObjectServices.getFullyQualifiedName('Run_Time__c'), 'ASC')) {

                String instanceName = result.Instance__r.Name;
                Id instanceId = result.Instance__r.Id;
                String instanceAppResult = result.Result__c;
                DateTime instanceAppResultTime = result.Run_Time__c;

                if (instanceId != null) {
                    ALMApplicationResultServices.InstanceWithLatestAndSuccessfulRunTime instanceResultToProcess = storedInstanceToRunTimes.get(instanceId);
                    if (instanceResultToProcess == null) {
                        instanceResultToProcess = new ALMApplicationResultServices.InstanceWithLatestAndSuccessfulRunTime(
                             instanceId,
                             instanceName,
                             instanceAppResult,
                             instanceAppResultTime
                         );
                    } else {
                        instanceResultToProcess.updateLatestRunTimes(instanceAppResult, instanceAppResultTime);
                    }
                    storedInstanceToRunTimes.put(instanceId, instanceResultToProcess);
                } else {
                    ALMLogServices.error(new ALMException('Application result with Salesforce ID ' + result.Id + ' attempted caching with a null instance lookup ID.'), ALMLogServices.Application.ADMIN_CONSOLE);
                }
            }
        }
        return storedState.getInstanceTimes();
    }

    public static Set<String> getDeletedInstanceNames () {
        Set<String> deletedInstanceNames = new Set<String>();
            for(Instances__c deletedInstanceFound : [SELECT Id, Name
                                                     FROM Instances__c
                                                     WHERE Is_Deleted__c = true]) {
                deletedInstanceNames.add(deletedInstanceFound.Name);
            }
        return deletedInstanceNames;
    }

    public static void scheduleComponentCleaningForDeletedInstances(Map<Id, Instances__c> oldInstanceIdToInstance, List<Instances__c> updatedInstances) {

        for(Instances__c updatedInstance : updatedInstances) {
            Instances__c oldVersionOfInstance = oldInstanceIdToInstance.get(updatedInstance.Id);
            if(updatedInstance.Is_Deleted__c == true && oldVersionOfInstance.Is_Deleted__c == false) {
                ComponentServices.scheduleSourceInstanceCleaner();
                break;
            }
        }
    }
}