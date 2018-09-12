public with sharing class DependentComponentWrapper extends ComponentSearchWrapper {
    public static final String DEPENDENCY_TYPE_DEPENDENT = 'Dependent';
    public static final String DEPENDENCY_TYPE_REFERENCE = 'Reference';
    public static final String DEPENDENCY_TYPE_ALL = 'All';
    
    @AuraEnabled
    public String dependencyType {get; set;}
    
    @AuraEnabled
    public List<Component__c> dependencyList {get; set;}

    public DependentComponentWrapper(Component__c comp,
                                     String parentName,
                                     String instance,
                                     DateTime lastModifiedDate,
                                     String lastModifiedBy,
                                     List<Component__c> dependencyList,
                                     String dependencyType) {
        super(comp, parentName, instance, lastModifiedDate, lastModifiedBy);
        this.isUnsupportedType = unsupportedTypesList.contains(comp.Type__c);
        this.dependencyList = dependencyList;
        this.dependencyType = dependencyType;
    }

}