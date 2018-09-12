public with sharing class DependentComponentServices {
    public static List<DependentComponentWrapper> constructDependentComponents(List<ComponentSearchWrapper> searchWrappers, 
                String relatedComponentsFilterChoice) {
        List<Component__c> documentedComponents = pluckComponentsFromWrappers(searchWrappers);
        
        Map<Id, Set<String>> componentIdToEnvironmentName = getComponentIdToEnvironmentNameMap(searchWrappers);

        Map<String,DependentComponentWrapper> dependentComponentIdAndEnvToWrapper = new Map<String,DependentComponentWrapper>();

        // All or Direct construct wrappers for parent and children
        if (String.isBlank(relatedComponentsFilterChoice) || !relatedComponentsFilterChoice.startsWithIgnoreCase(DependentComponentWrapper.DEPENDENCY_TYPE_REFERENCE)) {
            constructParentWrappers(documentedComponents, dependentComponentIdAndEnvToWrapper, componentIdToEnvironmentName);
            constructChildrenWrappers(documentedComponents, dependentComponentIdAndEnvToWrapper, componentIdToEnvironmentName);
        } 
        
        // Construct reference if choice is All or Reference
        if (String.isBlank(relatedComponentsFilterChoice) || !relatedComponentsFilterChoice.startsWithIgnoreCase(DependentComponentWrapper.DEPENDENCY_TYPE_DEPENDENT)) {
            constructReferenceWrappers(searchWrappers, dependentComponentIdAndEnvToWrapper, componentIdToEnvironmentName);
        }
        
        return dependentComponentIdAndEnvToWrapper.values();
    }

    private static Map<Id, Set<String>> getComponentIdToEnvironmentNameMap(List<ComponentSearchWrapper> searchWrappers) {
        Map<Id, Set<String>> componentIdToEnvironmentName = new Map<Id, Set<String>>();

        for (ComponentSearchWrapper searchWrapper : searchWrappers){
            if (!componentIdToEnvironmentName.containsKey(searchWrapper.component.Id)) {
                componentIdToEnvironmentName.put(searchWrapper.component.Id, new Set<String>{searchWrapper.environment});
            } else {
                componentIdToEnvironmentName.get(searchWrapper.component.Id).add(searchWrapper.environment);
            }
        }
        
        return componentIdToEnvironmentName;
    }
    
    private static void constructParentWrappers(List<Component__c> documentedComponents, 
                                  Map<String,DependentComponentWrapper> dependentComponentIdAndEnvToWrapper, 
                                  Map<Id, Set<String>> componentIdToEnvironmentName) {
        for (Component__c comp : [SELECT Name,
                                        Full_Name__c,
                                        Parent_Component__c,
                                        Parent_Component__r.Name,
                                        Parent_Component__r.Full_Name__c,
                                        Parent_Component__r.Type__c,
                                        Parent_Component__r.Id,
                                        Parent_Component__r.Parent_Component__r.Name,
                                        Parent_Component__r.Field_Modified_Data__c,
                                        Parent_Component__r.Key__c
                                 FROM Component__c
                                 WHERE ID IN :documentedComponents]) {
            Boolean hasParent = (comp.Parent_Component__c != null);

            if (hasParent) {
                // User has documented a Field type for example
                Component__c parentComp = (Component__c) comp.getSObject(SObjectServices.getFullyQualifiedName('Parent_Component__r'));
                String dependencyName = '';

                List<FieldModifiedData> fieldModifiedData = (List<FieldModifiedData>) JSON.deserialize(comp.Parent_Component__r.Field_Modified_Data__c, List<FieldModifiedData>.class);
                populateDependencyWrapperList( dependentComponentIdAndEnvToWrapper,
                                               componentIdToEnvironmentName,
                                               comp,
                                               parentComp,
                                               fieldModifiedData,
                                               dependencyName,
                                               DependentComponentWrapper.DEPENDENCY_TYPE_DEPENDENT);
            }
        }
    }
    
    private static void constructChildrenWrappers(List<Component__c> documentedComponents,
                                  Map<String,DependentComponentWrapper> dependentComponentIdAndEnvToWrapper, 
                                  Map<Id, Set<String>> componentIdToEnvironmentName) {
        // User has documented an object for example, create a wrapper for all children for each instance
        for (Component__c childComponent : [SELECT Id,
                                                   Name,
                                                   Full_Name__c,
                                                   Parent_Component__c,
                                                   Parent_Component__r.Name,
                                                   Parent_Component__r.Full_Name__c,
                                                   Parent_Component__r.Type__c,
                                                   Parent_Component__r.Id,
                                                   Parent_Component__r.Parent_Component__r.Name,
                                                   Parent_Component__r.Field_Modified_Data__c,
                                                   Type__c,
                                                   Field_Modified_Data__c
                                            FROM Component__c
                                            WHERE Parent_Component__c in :documentedComponents]) {
            Component__c comp = (Component__c) childComponent.getSObject(SObjectServices.getFullyQualifiedName('Parent_Component__r'));
            String dependencyName = comp.Name;
            List<FieldModifiedData> fieldModifiedData = (List<FieldModifiedData>) JSON.deserialize(childComponent.Field_Modified_Data__c, List<FieldModifiedData>.class);
            populateDependencyWrapperList( dependentComponentIdAndEnvToWrapper,
                                           componentIdToEnvironmentName,
                                           comp,
                                           childComponent,
                                           fieldModifiedData,
                                           dependencyName,
                                           DependentComponentWrapper.DEPENDENCY_TYPE_DEPENDENT);
        }
    }
    
    @TestVisible
    private static void constructReferenceWrappers(List<ComponentSearchWrapper> searchWrappers,
                    Map<String,DependentComponentWrapper> dependentComponentIdAndEnvToWrapper,
                    Map<Id, Set<String>> componentIdToEnvironmentName) {
        // Map of id of the reference component => a Map of environment name => List of Component records
        Map<Id, Map<String,List<Component__c>>> referenceComponentIdToDocumentedComponent = getReferenceComponentIdToDocumentedComponentMap(searchWrappers);
        Set<Id> referenceComponentIdSet = referenceComponentIdToDocumentedComponent.keySet();
        List<Component__c> referenceComponents = [SELECT Id,
                                                         Name,
                                                         Full_Name__c,
                                                         Type__c,
                                                         Field_Modified_Data__c, 
                                                         Parent_Component__r.Id,
                                                         Parent_Component__c,
                                                         Parent_Component__r.Name
                                                  FROM Component__c
                                                  WHERE ID IN :referenceComponentIdSet];
        
        for (Component__c referenceComponent : referenceComponents) {
            buildReferenceWrapper(referenceComponent, 
                                  referenceComponentIdToDocumentedComponent, 
                                  dependentComponentIdAndEnvToWrapper, 
                                  componentIdToEnvironmentName);
        }
    }
    
    @TestVisible
    private static Map<Id, Map<String,List<Component__c>>> getReferenceComponentIdToDocumentedComponentMap(List<ComponentSearchWrapper> searchWrappers) {
        Map<Id, Map<String,List<Component__c>>> referenceComponentIdToDocumentedComponent = new Map<Id, Map<String,List<Component__c>>>();
        
        for (ComponentSearchWrapper wrapper : searchWrappers) {
            String references = wrapper.componentReferences;
            if (String.isNotBlank(references)) {
                String wrapperEnvironment = wrapper.environment;
                Component__c wrapperComponent = wrapper.component;
                for (String referenceId : references.split(',')) {
                    Map<String, List<Component__c>> environmentToComponentMap = null;
                    List<Component__c> componentsList = null;
                    if (referenceComponentIdToDocumentedComponent.containsKey(referenceId)) {
                        environmentToComponentMap = referenceComponentIdToDocumentedComponent.get(referenceId);
                        if (environmentToComponentMap == null) {
                            environmentToComponentMap = new Map<String, List<Component__c>>();
                        }
                        
                        componentsList = environmentToComponentMap.get(wrapperEnvironment);
                        if (componentsList == null) {
                            componentsList = new List<Component__c>();
                        }
                    } else {
                        environmentToComponentMap = new Map<String, List<Component__c>>();
                        componentsList = new List<Component__c>();
                    }
                    
                    componentsList.add(wrapperComponent);
                    environmentToComponentMap.put(wrapperEnvironment, componentsList);
                    referenceComponentIdToDocumentedComponent.put(referenceId, environmentToComponentMap);
                }
            }
        }
        
        return referenceComponentIdToDocumentedComponent;
    }
    
    private static void buildReferenceWrapper(Component__c referenceComponent, 
                                Map<Id, Map<String,List<Component__c>>> referenceComponentIdToDocumentedComponent, 
                                Map<String,DependentComponentWrapper> dependentComponentIdAndEnvToWrapper, 
                                Map<Id, Set<String>> componentIdToEnvironmentName) {
        List<FieldModifiedData> referenceComponentFMD = (List<FieldModifiedData>) JSON.deserialize(referenceComponent.Field_Modified_Data__c, List<FieldModifiedData>.class);
            
        Map<String,List<Component__c>> documentedComponents = referenceComponentIdToDocumentedComponent.get(referenceComponent.Id);
        String parentComponentName = (referenceComponent.Parent_Component__c != null 
                                        && String.isNotBlank(referenceComponent.Parent_Component__r.Name)) ? referenceComponent.Parent_Component__r.Name : '';
        for (String env : documentedComponents.keySet()) {
            for (Component__c documentedComponent : documentedComponents.get(env)) {
                populateDependencyWrapperList( dependentComponentIdAndEnvToWrapper,
                                               env,
                                               componentIdToEnvironmentName,
                                               documentedComponent,
                                               referenceComponent,
                                               referenceComponentFMD,
                                               parentComponentName,
                                               DependentComponentWrapper.DEPENDENCY_TYPE_REFERENCE);
            }
        }
    }
    
    private static List<Component__c> pluckComponentsFromWrappers(List<ComponentSearchWrapper> searchWrappers) {
        List<Component__c> documentedComponents = new List<Component__c>();
        for (ComponentSearchWrapper wrapper : searchWrappers) {
            documentedComponents.add(wrapper.component);
        }

        return documentedComponents;
    }

    private static void populateDependencyWrapperList( Map<String,DependentComponentWrapper> dependentComponentIdAndEnvToWrapper,
                                                  Map<Id, Set<String>> componentIdToEnvironmentName,
                                                  Component__c comp,
                                                  Component__c parentComp,
                                                  List<FieldModifiedData> fieldModifiedData,
                                                  String parentComponentName, 
                                                  String dependencyType) {

        List<DependentComponentWrapper> wrappers = constructDependentComponentWrappers(componentIdToEnvironmentName,
                                                                                 comp,
                                                                                 parentComp,
                                                                                 fieldModifiedData,
                                                                                 parentComponentName,
                                                                                 dependencyType,
                                                                                 null);
        populateDependentComponentWrapperMap(dependentComponentIdAndEnvToWrapper, wrappers);
    }
    
    private static void populateDependencyWrapperList( Map<String,DependentComponentWrapper> dependentComponentIdAndEnvToWrapper,
                                                  String documentedCompEnvironment,
                                                  Map<Id, Set<String>> componentIdToEnvironmentName,
                                                  Component__c comp,
                                                  Component__c parentComp,
                                                  List<FieldModifiedData> fieldModifiedData,
                                                  String parentComponentName, 
                                                  String dependencyType) {
        List<DependentComponentWrapper> wrappers = constructDependentComponentWrappers(
                                                                              componentIdToEnvironmentName,
                                                                              comp,
                                                                              parentComp,
                                                                              fieldModifiedData,
                                                                              parentComponentName,
                                                                              dependencyType, 
                                                                              documentedCompEnvironment);
        populateDependentComponentWrapperMap(dependentComponentIdAndEnvToWrapper, wrappers);
    }
    
    @TestVisible
    private static List<DependentComponentWrapper> constructDependentComponentWrappers(
                                                  Map<Id, Set<String>> componentIdToEnvironmentName,
                                                  Component__c documentedComponent,
                                                  Component__c dependentComponent,
                                                  List<FieldModifiedData> dependentComponentFMD,
                                                  String parentComponentName, 
                                                  String dependencyType, 
                                                  String documentedComponentEnvironment) {
        List<DependentComponentWrapper> dependentComponentWrappers = new List<DependentComponentWrapper>();
        Set<String> documentedComponentEnvironmentNames = componentIdToEnvironmentName.get(documentedComponent.Id);

        //Get a set of environmentnames for the documented dependentcomponent.
        Set<String> dependentComponentEnvNames = componentIdToEnvironmentName.get(dependentComponent.Id);
        for (FieldModifiedData fmd : dependentComponentFMD) {
            // This will prevent duplicate entries in the documented components section
            if ((!documentedComponentEnvironmentNames.isEmpty() && 
                 !documentedComponentEnvironmentNames.contains(fmd.environmentName))
                    ||(dependentComponentEnvNames != null && 
                       dependentComponentEnvNames.contains(fmd.environmentName))) {
                continue;
            }
            
            String instance = fmd.environmentName;
            Datetime lastModifiedDate = fmd.lastModifiedDate;
            String lastModifiedBy = fmd.lastModifiedByName;
            DependentComponentWrapper wrapper = new DependentComponentWrapper(dependentComponent,
                                                                       parentComponentName,
                                                                       instance,
                                                                       lastModifiedDate,
                                                                       lastModifiedBy,
                                                                       new List<Component__c> {documentedComponent}, 
                                                                       dependencyType);
            wrapper.parentComponentId = dependentComponent.Parent_Component__r.Id;
            wrapper.isDeleted = fmd.deleted;
            
            if (dependencyType.startsWithIgnoreCase(DependentComponentWrapper.DEPENDENCY_TYPE_REFERENCE)) {
                // For reference types we only want to add the wrapper if the environment name matches 
                // the environment name of the documented component and if a wrapper has not already 
                // been created.  This prevents duplicate wrappers in the related components section
                if (fmd.environmentName == documentedComponentEnvironment) {
                    Boolean alreadyExists = false;
                    
                    for (DependentComponentWrapper dcw : dependentComponentWrappers) {
                        if (dcw.environment == wrapper.environment) {
                            alreadyExists = true;
                            break;
                        }
                    }
                    
                    if (!alreadyExists) {
                        dependentComponentWrappers.add(wrapper);
                    }
                }
            } else {
                dependentComponentWrappers.add(wrapper);
            }
        }
        
        return dependentComponentWrappers;
    }
    
    private static void populateDependentComponentWrapperMap(Map<String,DependentComponentWrapper> wrapperMap, 
                                                             List<DependentComponentWrapper> dependentComponentWrappers) {
        for (DependentComponentWrapper wrapper : dependentComponentWrappers) {
            DependentComponentWrapper existingDependentWrapper = wrapperMap.get(wrapper.component.Id + wrapper.environment);

            if (existingDependentWrapper != null) {
                existingDependentWrapper.dependencyList.addAll(wrapper.dependencyList);
                wrapperMap.put(wrapper.component.Id + wrapper.environment, existingDependentWrapper);
            } else {
                wrapperMap.put(wrapper.component.Id + wrapper.environment, wrapper);
            }
        }
    }
}