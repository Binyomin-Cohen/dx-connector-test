@isTest
private class TestDependentComponentServices {

    static testMethod void testConstructDependentComponents_componentWithChildren() {
        String instanceName1 = 'env0';
        String instanceName2 = 'env1';
        String testName = 'Test Component Name';
        String testParentName = 'Test Component Name PARENT';
        String testParentName2 = 'Test Component Name PARENT2';
        String testType = 'Test Component Type';
        String testParentType = 'Test Component Type PARENT';
        String instance = null;
        Integer NUM_CHILD_COMPS = 3;

        List<FieldModifiedData> fmd = new List<FieldModifiedData>{
            new FieldModifiedData(instanceName1),
            new FieldModifiedData(instanceName2)
        };

        String testFieldModifiedData = JSON.serialize(fmd);
        Component__c parentComp = TestingUtils.createComponent(testParentName, testParentType, instance);
        Component__c parentComp2 = TestingUtils.createComponent(testParentName2, testParentType, instance);

        List<Component__c> childComponents = new List<Component__c>();

        for (Integer i = 0; i < NUM_CHILD_COMPS; i++) {
            Component__c childComp = TestingUtils.buildComponentWithParent(testName + i, testType, parentComp.Id);
            childComp.Field_Modified_Data__c = testFieldModifiedData;
            childComponents.add(childComp);
        }
        Component__c childComponentToIgnore = TestingUtils.buildComponentWithParent(testName, testType, parentComp2.Id);

        childComponents.add(childComponentToIgnore);
        insert childComponents;

        childComponents = [SELECT Id,
                                  Name,
                                  Parent_Component__c
                           FROM Component__c
                           WHERE Id in :childComponents];

        List<ComponentSearchWrapper> documentedSearchWrappers = new List<ComponentSearchWrapper>{
             new ComponentSearchWrapper(parentComp,
                                  instanceName1,
                                  null,
                                  null,
                                  null,
                                  false)
        };

        Test.startTest();
            List<DependentComponentWrapper> actualDependentWrappers = 
              DependentComponentServices.constructDependentComponents(documentedSearchWrappers, 
                 DependentComponentWrapper.DEPENDENCY_TYPE_ALL);
        Test.stopTest();

        System.assertEquals(NUM_CHILD_COMPS, actualDependentWrappers.size(), 'The correct number of child components should be returned');
        Map<Id, Component__c> depCompIdToDepComponent = new Map<Id, Component__c>();

        for (DependentComponentWrapper depWrap : actualDependentWrappers) {
            depCompIdToDepComponent.put(depWrap.component.Id, depWrap.component);
            System.assertEquals(1, depWrap.dependencyList.size(), 'One documented component should be captured');
            System.assertEquals(testParentName, depWrap.dependencyList[0].Name,
                                    'The dependency name should be the parent component name');
            System.assertEquals(instanceName1, depWrap.environment,
                                    'The environment should be the parent environment');
            System.assertEquals(instanceName1 + '|' + depWrap.component.Id, depWrap.key, 'The key should be set correctly.');
        }

        for (Component__c expectedChildComponent : childComponents) {
            if (expectedChildComponent.id == childComponentToIgnore.Id) {
                continue;
            } else {
                Component__c dependentComponent = depCompIdToDepComponent.get(expectedChildComponent.id);
                System.assertNotEquals(null, dependentComponent, 'The correct component should be found');
                System.assertEquals(expectedChildComponent.Parent_Component__c, dependentComponent.Parent_Component__c,
                                    'The child component should be attached to the correct parent');
            }
        }

    }

    static testMethod void testConstructDependentComponents_documentChildComponent() {
        String instanceName = 'instance1';
        String instanceName2 = 'instance2';
        List<FieldModifiedData> fmd = new List<FieldModifiedData>{
            new FieldModifiedData(instanceName),
            new FieldModifiedData(instanceName2)
        };
        String testFieldModifiedData = JSON.serialize(fmd);

        String instanceId = null;
        String documentedComponentParentName = 'Test Component Name Parent';
        String documentedComponentParentType = 'Test type Parent';

        Component__c documentedComponentParentComponent = TestingUtils.buildComponent(documentedComponentParentName,
                                                            documentedComponentParentType, instanceId);
        documentedComponentParentComponent.Field_Modified_Data__c = testFieldModifiedData;

        String otherComponentParentName = 'Test Component Name Other Parent';
        String otherComponentParentType = 'Test type Other Parent Type';
        Component__c otherComponentParentComponent = TestingUtils.buildComponent(otherComponentParentName,
                                                                        otherComponentParentType, instanceId);
        otherComponentParentComponent.Field_Modified_Data__c = testFieldModifiedData;

        List<Component__c> parentComponents = new List<Component__c>();
        parentComponents.add(documentedComponentParentComponent);
        parentComponents.add(otherComponentParentComponent);

        insert parentComponents;

        String childComponentName = 'Test component name child';
        String childComponentType = 'Test component type child';

        Component__c childComp = TestingUtils.buildComponentWithParent(childComponentName,
                                                                    childComponentType,
                                                                    documentedComponentParentComponent.Id);
        childComp.Field_Modified_Data__c = testFieldModifiedData;
        insert childComp;

        List<ComponentSearchWrapper> documentedSearchWrappers = new List<ComponentSearchWrapper>{
                             new ComponentSearchWrapper(childComp,
                                  instanceName,
                                  null,
                                  null,
                                  null,
                                  false)
                            };

        Test.startTest();
            List<DependentComponentWrapper> actualDependentWrappers = 
              DependentComponentServices.constructDependentComponents(documentedSearchWrappers, 
                 DependentComponentWrapper.DEPENDENCY_TYPE_ALL);
        Test.stopTest();

        System.assertEquals(1, actualDependentWrappers.size(), 'The correct number of parent components should be returned');

        DependentComponentWrapper actualDependentWrapper = actualDependentWrappers[0];

        String documentedComponentParentParentName = '';
        String expectedDependencyValue = childComponentName;

        System.assertEquals(instanceName, actualDependentWrapper.environment,
            'The instance name in the audit history should be set in the wrapper');
        System.assertEquals(documentedComponentParentName, actualDependentWrapper.componentName,
            'The component name on the wrapper should be the name of the parent component');
        System.assertEquals(documentedComponentParentType, actualDependentWrapper.componentType,
            'The component type on the wrapper should be the type of the parent component');
        System.assertEquals(documentedComponentParentParentName, actualDependentWrapper.parentComponentName,
            'The parent component name on the wrapper should be the parent name of the parent component');
        System.assertEquals(1, actualDependentWrapper.dependencyList.size(), 'One documented component should be captured');
        System.assertEquals(childComponentName, actualDependentWrapper.dependencyList[0].Name,
            'The dependency name should be the documented child component name');
        System.assertEquals(instanceName + '|' + actualDependentWrapper.component.Id, actualDependentWrapper.key, 'The key should be set correctly.');
    }

    static testMethod void testConstructDependentComponents_documentChildComponentDifferentInstances() {
        String instanceName = 'instance1';
        String instanceName2 = 'instance2';
        List<FieldModifiedData> fmd = new List<FieldModifiedData>{
            new FieldModifiedData(instanceName),
            new FieldModifiedData(instanceName2)
        };
        String testFieldModifiedData = JSON.serialize(fmd);

        String instanceId = null;
        String documentedComponentParentName = 'Test Component Name Parent';
        String documentedComponentParentType = 'Test type Parent';

        Component__c documentedComponentParentComponent = TestingUtils.buildComponent(documentedComponentParentName,
                                                            documentedComponentParentType, instanceId);
        documentedComponentParentComponent.Field_Modified_Data__c = testFieldModifiedData;

        String otherComponentParentName = 'Test Component Name Other Parent';
        String otherComponentParentType = 'Test type Other Parent Type';
        Component__c otherComponentParentComponent = TestingUtils.buildComponent(otherComponentParentName,
                                                                        otherComponentParentType, instanceId);
        otherComponentParentComponent.Field_Modified_Data__c = testFieldModifiedData;

        List<Component__c> parentComponents = new List<Component__c>();
        parentComponents.add(documentedComponentParentComponent);
        parentComponents.add(otherComponentParentComponent);

        insert parentComponents;

        String childComponentName = 'Test component name child';
        String childComponentType = 'Test component type child';

        Component__c childComp = TestingUtils.buildComponentWithParent(childComponentName,
                                                                    childComponentType,
                                                                    documentedComponentParentComponent.Id);
        childComp.Field_Modified_Data__c = testFieldModifiedData;
        insert childComp;

        List<ComponentSearchWrapper> documentedSearchWrappers = new List<ComponentSearchWrapper>{
                             new ComponentSearchWrapper(childComp,
                                  instanceName,
                                  null,
                                  null,
                                  null,
                                  false),
                             new ComponentSearchWrapper(childComp,
                                  instanceName2,
                                  null,
                                  null,
                                  null,
                                  false)
                            };

        Test.startTest();
            List<DependentComponentWrapper> actualDependentWrappers = 
              DependentComponentServices.constructDependentComponents(documentedSearchWrappers, 
                 DependentComponentWrapper.DEPENDENCY_TYPE_ALL);
        Test.stopTest();

        System.assertEquals(2, actualDependentWrappers.size(), 'The correct number of parent components should be returned');

        String documentedComponentParentParentName = '';
        String expectedDependencyValue = childComponentName;
        Set<String>EXPECTED_INSTANCE_NAMES = new Set<String>{instanceName, instanceName2};
        Set<String>actualInstanceNames = new Set<String>();

        for (DependentComponentWrapper actualDependentWrapper : actualDependentWrappers) {
            System.assertEquals(documentedComponentParentName, actualDependentWrapper.componentName,
                'The component name on the wrapper should be the name of the parent component');
            System.assertEquals(documentedComponentParentType, actualDependentWrapper.componentType,
                'The component type on the wrapper should be the type of the parent component');
            System.assertEquals(documentedComponentParentParentName, actualDependentWrapper.parentComponentName,
                'The parent component name on the wrapper should be the parent name of the parent component');
            System.assertEquals(1, actualDependentWrapper.dependencyList.size(), 'One documented component should be captured');
            System.assertEquals(childComponentName, actualDependentWrapper.dependencyList[0].Name,
                'The dependency name should be the documented child component name');
            actualInstanceNames.add(actualDependentWrapper.environment);
            System.assertEquals(actualDependentWrapper.environment + '|' + actualDependentWrapper.component.Id, actualDependentWrapper.key, 'The key should be set correctly.');
        }

        System.assertEquals(EXPECTED_INSTANCE_NAMES, actualInstanceNames, 'The correct instance names should be captured');
    }

    static testMethod void testConstructDependentComponents_documentParentAndChildComponent() {
        String instanceName = 'instance1';
        String instanceName2 = 'instance2';
        List<FieldModifiedData> fmd = new List<FieldModifiedData>{
            new FieldModifiedData(instanceName),
            new FieldModifiedData(instanceName2)
        };
        String testFieldModifiedData = JSON.serialize(fmd);

        String instanceId = null;
        String documentedComponentParentName = 'Test Component Name Parent';
        String documentedComponentParentType = 'Test type Parent';

        Component__c documentedComponentParentComponent = TestingUtils.buildComponent(documentedComponentParentName,
                                                            documentedComponentParentType, instanceId);
        documentedComponentParentComponent.Field_Modified_Data__c = testFieldModifiedData;

        String otherComponentParentName = 'Test Component Name Other Parent';
        String otherComponentParentType = 'Test type Other Parent Type';
        Component__c otherComponentParentComponent = TestingUtils.buildComponent(otherComponentParentName,
                                                                        otherComponentParentType, instanceId);
        otherComponentParentComponent.Field_Modified_Data__c = testFieldModifiedData;

        List<Component__c> parentComponents = new List<Component__c>();
        parentComponents.add(documentedComponentParentComponent);
        parentComponents.add(otherComponentParentComponent);

        insert parentComponents;

        String childComponentName = 'Test component name child';
        String childComponentType = 'Test component type child';

        Component__c childComp = TestingUtils.buildComponentWithParent(childComponentName,
                                                                    childComponentType,
                                                                    documentedComponentParentComponent.Id);
        childComp.Field_Modified_Data__c = testFieldModifiedData;
        insert childComp;

        List<ComponentSearchWrapper> documentedSearchWrappers = new List<ComponentSearchWrapper>{
                             new ComponentSearchWrapper(childComp,
                                  instanceName,
                                  null,
                                  null,
                                  null,
                                  false),
                             new ComponentSearchWrapper(childComp,
                                  instanceName2,
                                  null,
                                  null,
                                  null,
                                  false),
                             new ComponentSearchWrapper(documentedComponentParentComponent,
                                  instanceName,
                                  null,
                                  null,
                                  null,
                                  false)
                            };

        Test.startTest();
            List<DependentComponentWrapper> actualDependentWrappers = 
                DependentComponentServices.constructDependentComponents(documentedSearchWrappers, 
                 DependentComponentWrapper.DEPENDENCY_TYPE_ALL);
        Test.stopTest();

        System.assertEquals(1, actualDependentWrappers.size(), 'Only one dependent component should be returned');

        DependentComponentWrapper actualDependentWrapper = actualDependentWrappers[0];

        String documentedComponentParentParentName = '';
        String expectedDependencyValue = childComponentName;

        System.assertEquals(instanceName2, actualDependentWrapper.environment,
            'The instance name in the audit history should be set in the wrapper');
        System.assertEquals(documentedComponentParentName, actualDependentWrapper.componentName,
            'The component name on the wrapper should be the name of the parent component');
        System.assertEquals(documentedComponentParentType, actualDependentWrapper.componentType,
            'The component type on the wrapper should be the type of the parent component');
        System.assertEquals(documentedComponentParentParentName, actualDependentWrapper.parentComponentName,
            'The parent component name on the wrapper should be the parent name of the parent component');
        System.assertEquals(1, actualDependentWrapper.dependencyList.size(), 'One documented component should be captured');
        System.assertEquals(childComponentName, actualDependentWrapper.dependencyList[0].Name,
            'The dependency name should be the documented child component name');
        System.assertEquals(instanceName2 + '|' + actualDependentWrapper.component.Id, actualDependentWrapper.key, 'The key should be set correctly.');
    }

    static testMethod void testConstructDependentComponents_documentMultipleChildrenUnderTheSameParent() {
        String instanceName = 'instance1';
        List<FieldModifiedData> fmd = new List<FieldModifiedData>{
            new FieldModifiedData(instanceName)
        };
        String testFieldModifiedData = JSON.serialize(fmd);

        String instanceId = null;
        String documentedComponentParentName = 'Test Component Name Parent';
        String documentedComponentParentType = 'Test type Parent';

        Component__c documentedComponentParentComponent = TestingUtils.buildComponent(documentedComponentParentName,
                                                            documentedComponentParentType, instanceId);
        documentedComponentParentComponent.Field_Modified_Data__c = testFieldModifiedData;

        insert documentedComponentParentComponent;

        String child1ComponentName = 'Test component name child';
        String child2ComponentName = 'Test component name child2';
        String childComponentType = 'Test component type child';

        Component__c childComp1 = TestingUtils.buildComponentWithParent(child1ComponentName,
                                                                    childComponentType,
                                                                    documentedComponentParentComponent.Id);

        childComp1.Field_Modified_Data__c = testFieldModifiedData;

        Component__c childComp2 = TestingUtils.buildComponentWithParent(child2ComponentName,
                                                                        childComponentType,
                                                                        documentedComponentParentComponent.Id);
        childComp2.Field_Modified_Data__c = testFieldModifiedData;
        insert new List<Component__c>{childComp1,childComp2};

        List<ComponentSearchWrapper> documentedSearchWrappers = new List<ComponentSearchWrapper>{
                             new ComponentSearchWrapper(childComp1,
                                  instanceName,
                                  null,
                                  null,
                                  null,
                                  false),
                             new ComponentSearchWrapper(childComp2,
                                  instanceName,
                                  null,
                                  null,
                                  null,
                                  false)
                            };

        Test.startTest();
            List<DependentComponentWrapper> actualDependentWrappers = 
              DependentComponentServices.constructDependentComponents(documentedSearchWrappers, 
                 DependentComponentWrapper.DEPENDENCY_TYPE_ALL);
        Test.stopTest();

        System.assertEquals(1, actualDependentWrappers.size(), 'Only one dependent component should be returned');

        DependentComponentWrapper actualDependentWrapper = actualDependentWrappers[0];

        String documentedComponentParentParentName = '';

        System.assertEquals(instanceName, actualDependentWrapper.environment,
            'The instance name in the audit history should be set in the wrapper');
        System.assertEquals(documentedComponentParentName, actualDependentWrapper.componentName,
            'The component name on the wrapper should be the name of the parent component');
        System.assertEquals(documentedComponentParentType, actualDependentWrapper.componentType,
            'The component type on the wrapper should be the type of the parent component');
        System.assertEquals(documentedComponentParentParentName, actualDependentWrapper.parentComponentName,
            'The parent component name on the wrapper should be the parent name of the parent component');
        System.assertEquals(2, actualDependentWrapper.dependencyList.size(), 'Two documented components should be captured');
        System.assertEquals(instanceName + '|' + actualDependentWrapper.component.Id, actualDependentWrapper.key, 'The key should be set correctly.');
        Set<String> actualComponentNames = new Set<String>();
        for (Component__c depComp : actualDependentWrapper.dependencyList) {
            actualComponentNames.add(depComp.Name);
        }
        System.assert(actualComponentNames.contains(child1ComponentName),
            'The dependency name should be the documented child component1 name');
        System.assert(actualComponentNames.contains(child2ComponentName),
            'The dependency name should be the documented child component2 name');
    }
    
    static testMethod void constructDependentComponentWrappers() {
        String documentedComponentInstanceName = 'instance-1';
        Instances__c documentedInstance = TestingUtils.createInstance(documentedComponentInstanceName);
        DateTime createdDate = DateTime.now();
        String createdBy = 'some-user';
        DateTime lastModifiedDate = createdDate.addDays(1);
        String lastModifiedBy = 'some-other-user';
        Boolean deleted = false;
        
        FieldModifiedData documentedComponentFMD = new FieldModifiedData(documentedComponentInstanceName, 
            lastModifiedDate, lastModifiedBy, createdDate, createdBy, deleted);
        
        String someOtherInstanceName = 'instance-2';
        FieldModifiedData otherFMD = new FieldModifiedData(someOtherInstanceName, 
            lastModifiedDate, lastModifiedBy, createdDate, createdBy, deleted);
            
        List<FieldModifiedData> dependentComponentFMD = new List<FieldModifiedData>();
        dependentComponentFMD.add(documentedComponentFMD);
        dependentComponentFMD.add(otherFMD);
        
        String documentedClassName = 'SomeClass';
        String documentedType = 'Apex Class';
        
        Component__c documentedComponent = TestingUtils.createUndocumentedComponent(documentedClassName, 
                                documentedType, documentedInstance.Id, documentedComponentFMD);
            
        String refCompName = 'SomeObject';
        String refCompType = 'Object';
        Component__c referenceComponent = TestingUtils.buildComponent(refCompName, refCompType,
            null);
        
        String dependencyName = '';
        Map<Id, Set<String>> componentIdToEnvironmentName = new Map<Id, Set<String>>();
        componentIdToEnvironmentName.put(documentedComponent.Id, 
                                         new Set<String>{documentedComponentInstanceName});
        
        Test.startTest();
            List<DependentComponentWrapper> actualWrappers = 
                DependentComponentServices.constructDependentComponentWrappers(componentIdToEnvironmentName,
                                                    documentedComponent,
                                                    referenceComponent,
                                                    dependentComponentFMD,
                                                    dependencyName,
                                                    DependentComponentWrapper.DEPENDENCY_TYPE_REFERENCE, 
                                                    documentedComponentInstanceName);
        Test.stopTest();
        
        System.assertEquals(1, actualWrappers.size(), 'One wrapper should have been returned');
        
        System.assertEquals(documentedComponentInstanceName, actualWrappers[0].environment, 
            'The environment name on the wrapper should match the documented component instance name');
        
        System.assertEquals(refCompName, actualWrappers[0].componentName, 
            'The component name on the wrapper should match the reference component name');
        
        System.assertEquals(refCompType, actualWrappers[0].componentType, 
            'The component type on the wrapper should match the reference component type');
        
        System.assertEquals(lastModifiedDate, actualWrappers[0].lastModifiedDate, 
            'The last modified date on the wrapper should match the reference component last modified date');
        
        System.assertEquals(lastModifiedBy, actualWrappers[0].lastModifiedBy, 
            'The last modified by on the wrapper should match the reference component last modifed by');
        
        System.assertEquals(1, actualWrappers[0].dependencyList.size(), 
            'The dependency list should contain one component');
        
        String expectedDependencyName = documentedClassName;
        String actualDependencyName = actualWrappers[0].dependencyList[0].Name;
        
        System.assertEquals(expectedDependencyName, actualDependencyName, 
            'The dependency name of the reference component should be the name of the documented class');
        
        System.assertEquals(DependentComponentWrapper.DEPENDENCY_TYPE_REFERENCE, 
                actualWrappers[0].dependencyType, 'The depenency type should be Reference');
    }
    
    static testMethod void getReferenceComponentIdToDocumentedComponentMap_singleComponentForInstance() {
        String instanceName = 'documentedInstance';
        Instances__c documentedInstance = TestingUtils.createInstance(instanceName);
        Backlog__c backlog = TestingUtils.createBacklogItem();
        
        String documentedClassName = 'SomeClass';
        String referenceClassName = 'SomeOtherClass';
        String documentedType = 'Apex Class';
        
        Component__c documentedApexClass = TestingUtils.createUndocumentedComponent(documentedClassName, documentedType, documentedInstance.Id, new FieldModifiedData(instanceName));
        Component__c referenceClass = TestingUtils.createUndocumentedComponent(referenceClassName, documentedType, documentedInstance.Id, new FieldModifiedData(instanceName));
        
        Backlog_Component__c backlogComponent = new Backlog_Component__c(Backlog__c = backlog.Id);
        backlogComponent.Component__c = documentedApexClass.Id;
        backlogComponent.Source_Sandbox__c = instanceName;
        
        insert new List<Backlog_Component__c> {backlogComponent};
        
        String documentedApexClassComponentReferences = referenceClass.Id;
        
        List<ComponentSearchWrapper> documentedSearchWrappers = new List<ComponentSearchWrapper>();
        documentedSearchWrappers.add(new ComponentSearchWrapper(documentedApexClass,
                              backlogComponent,
                              null,
                              null,
                              false,
                              documentedApexClassComponentReferences));
        
        Test.startTest();
            Map<Id, Map<String,List<Component__c>>> actualMap = 
                      DependentComponentServices.getReferenceComponentIdToDocumentedComponentMap(
                        documentedSearchWrappers
                      );
        Test.stopTest();
        
        Map<Id, Map<String,List<Component__c>>> expectedMap = new Map<Id, Map<String,List<Component__c>>>();
        Map<String, List<Component__c>> expectedReferenceMap = new Map<String, List<Component__c>>();
        expectedReferenceMap.put(instanceName, new List<Component__c>{documentedApexClass});
        
        expectedMap.put(referenceClass.Id, expectedReferenceMap); 
        System.assertEquals(expectedMap.size(), actualMap.size(), 
            'The method should return 1 entry in the Map');
        
        Map<String, List<Component__c>> actualReferenceMap = actualMap.get(referenceClass.Id);
        System.assertEquals(1, actualReferenceMap.size(), 
        'The reference id in the map should contain a list of all components where the reference is found');
        
        System.assert(actualReferenceMap.containsKey(instanceName), 
            'The documented instance name should exist in the reference map');
        
        System.assertEquals(1, actualReferenceMap.get(instanceName).size(), 
            'There should only be one component in the list');
            
        System.assertEquals(documentedApexClass.Id, actualReferenceMap.get(instanceName)[0].Id, 
            'The component id should be the id of the documented component');
    }
    
    static testMethod void getReferenceComponentIdToDocumentedComponentMap_multipleComponentsForInstance() {
        String instanceName = 'documentedInstance';
        Instances__c documentedInstance = TestingUtils.createInstance(instanceName);
        Backlog__c backlog = TestingUtils.createBacklogItem();
        
        String documentedClassName = 'SomeClass';
        String documentedClassName2 = 'SomeClass2';
        String referenceClassName = 'SomeOtherClass';
        String documentedType = 'Apex Class';
        
        String referenceObjectName = 'SomeObject';
        String referenceType = 'Object';
        
        Component__c documentedApexClass1 = TestingUtils.createComponent(documentedClassName, documentedType, null);
        Component__c documentedApexClass2 = TestingUtils.createComponent(documentedClassName2, documentedType, null);
        Component__c referenceClass = TestingUtils.createComponent(referenceClassName, documentedType, null);
        Component__c referenceObject = TestingUtils.createComponent(referenceObjectName, referenceType, null);
        
        Backlog_Component__c backlogComponent = new Backlog_Component__c(Backlog__c = backlog.Id);
        backlogComponent.Component__c = documentedApexClass1.Id;
        backlogComponent.Source_Sandbox__c = instanceName;
        
        Backlog_Component__c backlogComponent2 = new Backlog_Component__c(Backlog__c = backlog.Id);
        backlogComponent2.Component__c = documentedApexClass2.Id;
        backlogComponent2.Source_Sandbox__c = instanceName;
        
        insert new List<Backlog_Component__c> {backlogComponent, backlogComponent2};
        
        String documentedApexClassComponentReferences = referenceClass.Id + ',' + referenceObject.Id;
        
        List<ComponentSearchWrapper> documentedSearchWrappers = new List<ComponentSearchWrapper>();
        documentedSearchWrappers.add(new ComponentSearchWrapper(documentedApexClass1,
                              backlogComponent,
                              null,
                              null,
                              false,
                              documentedApexClassComponentReferences));
        
        documentedSearchWrappers.add(new ComponentSearchWrapper(documentedApexClass2,
                              backlogComponent2,
                              null,
                              null,
                              false,
                              documentedApexClassComponentReferences));
        
        Test.startTest();
            Map<Id, Map<String,List<Component__c>>> actualMap = 
                      DependentComponentServices.getReferenceComponentIdToDocumentedComponentMap(
                        documentedSearchWrappers
                      );
        Test.stopTest();
        
        Map<Id, Map<String,List<Component__c>>> expectedMap = new Map<Id, Map<String,List<Component__c>>>();
        Map<String, List<Component__c>> expectedReferenceMap = new Map<String, List<Component__c>>();
        expectedReferenceMap.put(documentedInstance.Name, new List<Component__c>{documentedApexClass1, documentedApexClass2});
        
        expectedMap.put(referenceClass.Id, expectedReferenceMap); 
        expectedMap.put(referenceObject.Id, expectedReferenceMap); 
        
        System.assertEquals(expectedMap.size(), actualMap.size(), 'The method should return 2 entries in the Map');
        
        Map<String, List<Component__c>> actualReferenceMap = actualMap.get(referenceClass.Id);
        System.assertEquals(1, actualReferenceMap.size(), 
        'The reference id in the map should contain a list of all components where the reference is found');
        
        System.assert(actualReferenceMap.containsKey(documentedInstance.Name), 
            'The documented instance name should exist in the reference map');
        
        System.assertEquals(2, actualReferenceMap.get(documentedInstance.Name).size(), 
            'There should be two components in the list');
        
        System.assertEquals(documentedApexClass1.Id, actualReferenceMap.get(documentedInstance.Name)[0].Id, 
            'The component id should be the id of the documented component');
            
        System.assertEquals(documentedApexClass2.Id, actualReferenceMap.get(documentedInstance.Name)[1].Id, 
            'The component id should be the id of the documented component');
    }
    
    /**
    * Document a class that has a reference to another apex class
    */
    static testMethod void constructReferenceWrappers_singleComponentForInstance() {
        Boolean setupMultipleInstanceFMD = false;
        Boolean createParentComponent = false;
        setupAndExecuteReferenceTestsForSingleComponent(setupMultipleInstanceFMD, createParentComponent);
    }

    static testMethod void constructReferenceWrappers_singleComponentForInstance_withParent() {
        Boolean setupMultipleInstanceFMD = false;
        Boolean createParentComponent = true;
        setupAndExecuteReferenceTestsForSingleComponent(setupMultipleInstanceFMD, createParentComponent);
    }
    
    static testMethod void constructReferenceWrappers_singleComponentForMultipleInstances() {
        Boolean setupMultipleInstanceFMD = true;
        Boolean createParentComponent = false;
        setupAndExecuteReferenceTestsForSingleComponent(setupMultipleInstanceFMD, createParentComponent);
    }
    
    static testMethod void constructReferenceWrappers_singleComponentForMultipleInstances_withParent() {
        Boolean setupMultipleInstanceFMD = true;
        Boolean createParentComponent = true;
        setupAndExecuteReferenceTestsForSingleComponent(setupMultipleInstanceFMD, createParentComponent);
    }
    
    /**
    * Document 2 classes, each having a reference to a class and an object
    */
    static testMethod void constructReferenceWrappers_multipleComponentsForInstance() {
        Boolean setupMultipleInstanceFMD = false;
        setupAndExecuteReferenceTestsForMultipleComponents(setupMultipleInstanceFMD);
    }
    
    static testMethod void constructReferenceWrappers_multipleComponentsForMultipeInstances() {
        Boolean setupMultipleInstanceFMD = true;
        setupAndExecuteReferenceTestsForMultipleComponents(setupMultipleInstanceFMD);
    }
    
    private static void setupAndExecuteReferenceTestsForSingleComponent(Boolean setupMultipleInstanceFMD, boolean createParentComponent) {
        Component__c referenceComponentParent;
        String instanceName = 'documentedInstance';
        List<FieldModifiedData> fmd = createFieldModifiedData(instanceName, setupMultipleInstanceFMD);
        
        Instances__c documentedInstance = TestingUtils.createInstance(instanceName);
        Backlog__c backlog = TestingUtils.createBacklogItem();
        
        String documentedClassName = 'SomeClass';
        String referenceComponentName = 'SomeOtherComponent';
        String documentedType = 'Apex Class';
        
        Component__c documentedApexClass = TestingUtils.createUndocumentedComponent(documentedClassName, documentedType, documentedInstance.Id, fmd);
        Component__c referenceComponent = TestingUtils.createUndocumentedComponent(referenceComponentName, documentedType, documentedInstance.Id, fmd);
        
        if(createParentComponent) {
            referenceComponentParent = TestingUtils.createUndocumentedComponent(referenceComponentName + '_parent', documentedType, documentedInstance.Id, fmd);
            referenceComponent.Parent_Component__c = referenceComponentParent.Id;
            update referenceComponent;
        }
        
        Backlog_Component__c backlogComponent = new Backlog_Component__c(Backlog__c = backlog.Id);
        backlogComponent.Component__c = documentedApexClass.Id;
        backlogComponent.Source_Sandbox__c = instanceName;
        
        insert new List<Backlog_Component__c> {backlogComponent};
        
        String documentedApexClassComponentReferences = referenceComponent.Id;
        
        List<ComponentSearchWrapper> documentedSearchWrappers = new List<ComponentSearchWrapper>();
        documentedSearchWrappers.add(new ComponentSearchWrapper(documentedApexClass,
                              backlogComponent,
                              null,
                              null,
                              false,
                              documentedApexClassComponentReferences));
                              
        Map<String,DependentComponentWrapper> dependentComponentIdAndEnvToWrapper = new Map<String,DependentComponentWrapper>();
        
        Map<Id, Set<String>> componentIdToEnvironmentName = new Map<Id, Set<String>>();
        componentIdToEnvironmentName.put(documentedApexClass.Id, new Set<String>{instanceName});
        
        Test.startTest();
            DependentComponentServices.constructReferenceWrappers(
                        documentedSearchWrappers,
                        dependentComponentIdAndEnvToWrapper,
                        componentIdToEnvironmentName
                      );
        Test.stopTest();
        
        System.assertEquals(1, dependentComponentIdAndEnvToWrapper.size(), 
            'The method should populate 1 wrapper into the Map');
        
        String expectedKey = referenceComponent.Id + instanceName;
        DependentComponentWrapper actualWrapper = dependentComponentIdAndEnvToWrapper.get(expectedKey);
        
        System.assertNotEquals(null, actualWrapper, 'The key should exist in the wrapper map');
        
        System.assertEquals(DependentComponentWrapper.DEPENDENCY_TYPE_REFERENCE, actualWrapper.dependencyType, 
            'The dependency type should be reference');
        
        System.assertEquals(instanceName, actualWrapper.environment, 
            'The environment name should be from the documented component');
            
        System.assertEquals(1, actualWrapper.dependencyList.size(), 
            'There should be 1 component in the dependency list');
        
        System.assertEquals(documentedClassName, actualWrapper.dependencyList[0].Name, 
            'The dependency name should be the name of the documented apex class');
            
        System.assertEquals(referenceComponent.Id, actualWrapper.component.Id, 
            'The component id of the wrapper should be the id of the reference component');
        
        if(createParentComponent) {
            System.assertEquals(referenceComponentParent.Id, actualWrapper.parentComponentId, 
                'The parent component id of the wrapper should be the id of the parent reference component');

            System.assertEquals(referenceComponentParent.Name, actualWrapper.parentComponentName, 
                'The parent component name of the wrapper should be the name of the parent reference component');
        }
    }
    
    private static void setupAndExecuteReferenceTestsForMultipleComponents(Boolean setupMultipleInstanceFMD) {
        String instanceName = 'documentedInstance';
        List<FieldModifiedData> fmd = createFieldModifiedData(instanceName, setupMultipleInstanceFMD);
        
        Instances__c documentedInstance = TestingUtils.createInstance(instanceName);
        Backlog__c backlog = TestingUtils.createBacklogItem();
        
        String documentedClassName = 'SomeClass';
        String documentedClassName2 = 'SomeClass2';
        String referenceClassName = 'SomeOtherClass';
        String documentedType = 'Apex Class';
        
        String referenceObjectName = 'SomeObject';
        String referenceType = 'Object';
        
        Component__c documentedApexClass1 = TestingUtils.createUndocumentedComponent(documentedClassName, documentedType, documentedInstance.Id, fmd);
        Component__c documentedApexClass2 = TestingUtils.createUndocumentedComponent(documentedClassName2, documentedType, documentedInstance.Id, fmd);
        Component__c referenceClass = TestingUtils.createUndocumentedComponent(referenceClassName, documentedType, documentedInstance.Id, fmd);
        Component__c referenceObject = TestingUtils.createUndocumentedComponent(referenceObjectName, referenceType, documentedInstance.Id, fmd);
        
        Backlog_Component__c backlogComponent = new Backlog_Component__c(Backlog__c = backlog.Id);
        backlogComponent.Component__c = documentedApexClass1.Id;
        backlogComponent.Source_Sandbox__c = instanceName;
        
        Backlog_Component__c backlogComponent2 = new Backlog_Component__c(Backlog__c = backlog.Id);
        backlogComponent2.Component__c = documentedApexClass2.Id;
        backlogComponent2.Source_Sandbox__c = instanceName;
        
        insert new List<Backlog_Component__c> {backlogComponent, backlogComponent2};
        
        String documentedApexClassComponentReferences = referenceClass.Id + ',' + referenceObject.Id;
        
        List<ComponentSearchWrapper> documentedSearchWrappers = new List<ComponentSearchWrapper>();
        documentedSearchWrappers.add(new ComponentSearchWrapper(documentedApexClass1,
                              backlogComponent,
                              null,
                              null,
                              false,
                              documentedApexClassComponentReferences));
        
        documentedSearchWrappers.add(new ComponentSearchWrapper(documentedApexClass2,
                              backlogComponent2,
                              null,
                              null,
                              false,
                              documentedApexClassComponentReferences));
                              
        Map<String,DependentComponentWrapper> dependentComponentIdAndEnvToWrapper = new Map<String,DependentComponentWrapper>();
        
        Map<Id, Set<String>> componentIdToEnvironmentName = new Map<Id, Set<String>>();
        componentIdToEnvironmentName.put(documentedApexClass1.Id, new Set<String>{instanceName});
        componentIdToEnvironmentName.put(documentedApexClass2.Id, new Set<String>{instanceName});
        
        Test.startTest();
            DependentComponentServices.constructReferenceWrappers(
                        documentedSearchWrappers,
                        dependentComponentIdAndEnvToWrapper,
                        componentIdToEnvironmentName
                      );
        Test.stopTest();
        
        System.assertEquals(2, dependentComponentIdAndEnvToWrapper.size(), 
            'The method should populate 2 wrappers into the Map');
        
        Set<Id> expectedReferenceComponentIds = new Set<Id>{referenceClass.Id, referenceObject.Id};
        Set<Id> actualReferenceComponentIds = new Set<Id>();
        
        Set<String> expectedDependencyListNames = new Set<String>{documentedClassName, documentedClassName2};
        Set<String> actualDependencyListNames = new Set<String>();
        
        for (String key : dependentComponentIdAndEnvToWrapper.keySet()) {
            DependentComponentWrapper referenceWrapper = dependentComponentIdAndEnvToWrapper.get(key);
            System.assertNotEquals(null, referenceWrapper, 'The key should exist in the wrapper map');
            
            System.assertEquals(DependentComponentWrapper.DEPENDENCY_TYPE_REFERENCE, 
                referenceWrapper.dependencyType, 'The dependency type should be reference');
                
            System.assertEquals(instanceName, referenceWrapper.environment, 
                'The environment name should be from the documented component');
                
            System.assertEquals(2, referenceWrapper.dependencyList.size(), 
                'There should be 2 component in the dependency list');
            
            actualDependencyListNames.add(referenceWrapper.dependencyList[0].Name);
            actualDependencyListNames.add(referenceWrapper.dependencyList[1].Name);
            
            actualReferenceComponentIds.add(referenceWrapper.component.Id);
        }
        
        for (Id expectedId : expectedReferenceComponentIds) {
            System.assert(actualReferenceComponentIds.contains(expectedId), 
                'The component id of the wrapper should be the id of the reference component');
        }
        
        for (String expectedDependencyName : expectedDependencyListNames) {
            System.assert(actualDependencyListNames.contains(expectedDependencyName), 
                'The dependency name should be the name of the documented apex class');
        }
    }
    
    private static List<FieldModifiedData> createFieldModifiedData(String instanceName, 
                                                            Boolean setupMultipleInstanceFMD) {
        List<FieldModifiedData> fmd = new List<FieldModifiedData>();
        fmd.add(new FieldModifiedData(instanceName));
        if (setupMultipleInstanceFMD) {
            String otherInstanceName = 'otherInstanceName';
            fmd.add(new FieldModifiedData(otherInstanceName));
        }
        
        return fmd;
    }
}