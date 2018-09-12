global virtual with sharing class ComponentSearchWrapper implements Comparable{
    @AuraEnabled
    public Boolean checked {get; set;}
    @AuraEnabled
    public Backlog_Component__c backlogComponent {get; set;}
    @AuraEnabled
    public Component__c component {get; set;}
    @AuraEnabled
    public String environment {get; set;}
    @AuraEnabled
    public String notes {get; set;}
    @AuraEnabled
    public Boolean isUnsupportedType {get; set;}
    @AuraEnabled
    public Datetime lastModifiedDate {get; set;}
    @AuraEnabled
    public String lastModifiedBy {get; set;}
    @AuraEnabled
    public Boolean existsOnCurrentBacklog {get; set;}
    @AuraEnabled
    public Boolean isDeleted {get; set;}

    @AuraEnabled
    public String componentType {get; set;}
    @AuraEnabled
    public Id parentComponentId {get; set;}
    @AuraEnabled
    public String parentComponentName {get; set;}
    @AuraEnabled
    public Boolean deployManually {get; set;}
    
    @AuraEnabled
    public String componentReferences {get; set;}

    // Holds the key calculated for uniqueness (used in front end)

    public String key;
    @AuraEnabled
    public String componentName {get; set;}

    public static Set<String> unsupportedTypesList {
        get {
            if (unsupportedTypesList == null) {
                unsupportedTypesList = new Set<String>();

                List<UnsupportedMetadataTypes__c> customSetting = UnsupportedMetadataTypes__c.getAll().values();
                for (UnsupportedMetadataTypes__c record : customSetting) {
                    unsupportedTypesList.add(record.Name__c);
                }
            }

            return unsupportedTypesList;
        }
    }

    public static Boolean sortDescending
    {
        get
        {
            if(sortDescending == null)
                sortDescending = true;
            return sortDescending;
        }
        set;
    }

    public ComponentSearchWrapper(){}

    public ComponentSearchWrapper(Component__c comp,
                                     String parentName,
                                     String instance,
                                     DateTime lastModifiedDate,
                                     String lastModifiedBy) {
        this.component = comp;
        this.componentName = comp.Name;
        this.componentType = comp.Type__c;
        this.parentComponentName = parentName;
        this.environment = instance;
        this.key = getKey();
        this.lastModifiedDate = lastModifiedDate;
        this.lastModifiedBy = lastModifiedBy;
    }

    public ComponentSearchWrapper(Component__c component,
                                  String environment,
                                  String notes,
                                  Datetime lastModifiedDate,
                                  String lastModifiedBy,
                                  Boolean isDeleted) {

        this(component, lastModifiedDate, lastModifiedBy);
        this.environment = environment;
        this.notes = notes;
        this.key = getKey();
        this.isDeleted = isDeleted != null ? isDeleted : false;
    }

    public ComponentSearchWrapper(Component__c component, FieldModifiedData fmd) {
        // Empty string is for notes. When creating from FieldModifiedData, notes will be empty.
        this(component, fmd.environmentName, '',  fmd.lastModifiedDate, fmd.lastModifiedByName, fmd.deleted);
    }

    public ComponentSearchWrapper(Component__c component,
                             Backlog_Component__c backlogComponent,
                             Datetime lastModifiedDate,
                             String lastModifiedBy,
                             Boolean isDeleted) {

        this(component, lastModifiedDate, lastModifiedBy);
        this.backlogComponent = backlogComponent;
        this.environment = backlogComponent.Source_Sandbox__c;
        this.notes = backlogComponent.Notes__c;
        this.deployManually = backlogComponent.Deploy_Manually__c;
        this.backlogComponent.Component__r = null;
        this.isDeleted = isDeleted != null ? isDeleted : false;
    }

    public ComponentSearchWrapper(Component__c component,
                             Backlog_Component__c backlogComponent,
                             Datetime lastModifiedDate,
                             String lastModifiedBy,
                             Boolean isDeleted,
                             String componentReferences) {

        this(component, backlogComponent, lastModifiedDate, lastModifiedBy, isDeleted);
        this.componentReferences = componentReferences;
    }
    
    @TestVisible
    private ComponentSearchWrapper(Component__c component,
                             Datetime lastModifiedDate,
                             String lastModifiedBy) {

        Component__c comp = component.clone(true, true, true, true);
        comp.Field_Modified_Data__c = null;
        this.component = comp;
        this.isUnsupportedType = unsupportedTypesList.contains(comp.Type__c);
        this.deployManually = this.isUnsupportedType;
        this.lastModifiedDate = lastModifiedDate;
        this.lastModifiedBy = lastModifiedBy;
        this.existsOnCurrentBacklog = false;
        this.checked = false;
        this.componentName = ComponentServices.getComponentName(comp);

        this.componentType = comp.Type__c;
        this.parentComponentName = ComponentServices.getComponentName(component.Parent_Component__r);
        this.parentComponentId = component.Parent_Component__r.Id;
    }

    @AuraEnabled
    public String getKey() {
        String environment = (environment == null) ? '' : environment;
        return environment + '|' + String.valueOf( component.Id );
    }

    public static ComponentSearchWrapper addWrapper(List<ComponentSearchWrapper> wrapperList,
                                  Component__c component,
                                  String environment,
                                  String notes,
                                  Datetime lastModifiedDate,
                                  String lastModifiedBy,
                                  Boolean isDeleted) {

        ComponentSearchWrapper wrapper = new ComponentSearchWrapper(component, environment, notes, lastModifiedDate, lastModifiedBy, isDeleted);
        wrapperList.add(wrapper);
        return wrapper;
    }

    public static ComponentSearchWrapper addWrapper(List<ComponentSearchWrapper> wrapperList,
                                  Backlog_Component__c backlogComponent,
                                  Component__c component,
                                  String environment,
                                  Datetime lastModifiedDate,
                                  String lastModifiedBy,
                                  Boolean isDeleted) {

        backlogComponent.Source_Sandbox__c = environment;
        // parse ref data 
        String referencesJSONString = getReferencesStringJSON(component);
        
        String componentReferences = '';
        if (String.isNotBlank(referencesJSONString)) {
            List<ComponentReference> cr = (List<ComponentReference>) JSON.deserialize(referencesJSONString, List<ComponentReference>.class);
            Set<String> ids = new Set<String>();
            for (ComponentReference compRef : cr) {
                if (compRef.instance.equalsIgnoreCase(environment)) {
                    componentReferences = compRef.references;
                    break;
                }
            }
        }
        
        ComponentSearchWrapper wrapper = new ComponentSearchWrapper(component, backlogComponent, 
            lastModifiedDate, lastModifiedBy, isDeleted, componentReferences);
        wrapperList.add(wrapper);
        return wrapper;
    }

    /**
     * Custom sorter to sort by Last Modified Date in descending order
     */
    global Integer compareTo(Object compareTo) {
        ComponentSearchWrapper compareToWrapper = (ComponentSearchWrapper) compareTo;
        if (lastModifiedDate == compareToWrapper.lastModifiedDate) {
            return 0;
        }
        else if (lastModifiedDate == null
            || (lastModifiedDate < compareToWrapper.lastModifiedDate)) {
            return (sortDescending) ? 1 : -1;
        }
        else {
            return (sortDescending) ? -1 : 1;
        }
    }

    public override String toString() {
        return '[' +environment + ':' + ComponentServices.getComponentName(component) + ':' + component.Type__c + ':' +  component.Parent_Component__c + ']';
    }
    
    @TestVisible
    private static String getReferencesStringJSON(Component__c c) {
        String json = '';
        
        Integer maxNumberOfFields = 5;
        
        for (Integer i=1; i<=maxNumberOfFields; i++) {
            String fieldValue = (String) c.get('Reference_Data_' + i + '__c');
            if (String.isNotBlank(fieldValue)) {
                json += fieldValue;
            }
        }
        
        return json;
    }
    
    public class ComponentReference {
        public String instance;
        public String references;
    
        public ComponentReference() {}
    
        public ComponentReference(String instance, String references) {
            this.instance = instance;
            this.references = references;
        }
    }

}