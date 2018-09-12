@isTest
public class TestComponentDocServices {

    private static final Set<String> EXPECTED_COMP_DOC_QUERIED_FIELDS = new Set<String> {
            'Id', 'Name', 'Full_Name__c', 'Type__c', 'Deleted__c', 'Parent_Component__c',
            'Parent_Component__r', 'Field_Modified_Data__c', 'Overall_Last_Modified_Date__c'};

    static List<Component__c> createComponents(Integer numComps) {
        Instances__c instance = TestingUtils.createInstance('test instance');
        Component__c parentComp = TestingUtils.createComponent('parent_comp', 'type', instance.Id);

        List<Component__c> comps = new List<Component__c>();
        for (Integer i = 0; i < numComps; i++) {
            Component__c comp = TestingUtils.buildComponentWithParent('comp_' + String.valueOf(i), 'type', parentComp.Id);
            comp.Overall_Last_Modified_Date__c = datetime.now();
            comp.Instance__c = instance.Id;
            comps.add(comp);
        }
        insert comps;
        return comps;
    }

    static testmethod void cachingComponentIds() {
        List<Component__c> comps = createComponents(10);
        Set<Id> compIds = (new Map<Id, Component__c>(comps)).keySet();

        Test.startTest();
            ComponentDocServices.cacheRecentlyModifiedComponents(new List<Id>(compIds));
        Test.stopTest();

        List<Id> compIdsFromCache = ComponentDocServices.getCachedRecentlyModifiedComponents();

        System.assertEquals(compIds.size(), compIdsFromCache.size(),
                            'There should exist the same number of components after retrieving from the cache');

        System.assertEquals(compIds, new Set<Id>(compIdsFromCache), 'The component Ids should be the same');
    }

    static testmethod void getEmptyCache() {
        Test.startTest();
            List<Id> cachedIds = ComponentDocServices.getCachedRecentlyModifiedComponents();
        Test.stopTest();

        System.assert(cachedIds.isEmpty(),
                'If there are no components in the cache, the cache should return an empty list of Ids.');
    }

    static testmethod void requeryingComponentsFromIdList() {
        List<Component__c> comps = createComponents(10);
        Set<Id> compIds = (new Map<Id, Component__c>(comps)).keySet();

        Test.startTest();
            List<Component__c> requeriedComps = ComponentDocServices.queryComponentsByIds(new List<Id>(compIds));
        Test.stopTest();

        Set<Id> requeriedCompIds = (new Map<Id, Component__c>(requeriedComps)).keySet();

        // Test that requeried components are the same as the initial components
        System.assertEquals(comps.size(), requeriedComps.size(),
                            'There should exist the same number of components after requerying the ids');

        System.assertEquals(requeriedCompIds, compIds, 'The requeried component ids should be the same');

        //  Test that the components that are queried have the required fields
        Set<String> queriedFields = (requeriedComps[0].getPopulatedFieldsAsMap()).keySet();
        Set<String> missingFields = new Set<String>();
        for ( String field : EXPECTED_COMP_DOC_QUERIED_FIELDS ) {
            String expectedField = ( field == 'Id' || field == 'Name' ) ?
                                   field : SObjectServices.getFullyQualifiedName(field);
            if (!queriedFields.contains(expectedField)) {
                missingFields.add(expectedField);
            }
        }

        System.assert(missingFields.isEmpty(),
                     'All of the required component fields should exist; the missing fields: ' + String.valueOf(missingFields));

        System.assert(String.isNotBlank(requeriedComps[0].Parent_Component__r.Full_Name__c),
                      'The Parent Component should have a Full Name');
        System.assert(String.isNotBlank(requeriedComps[0].Parent_Component__r.Name),
                      'The Parent Component should have a Name');
    }

    static testmethod void creatingComponentSearchWrappersFromComps_WithFMD() {
        List<String> envs = new List<String>{'env0', 'env1', 'env2'};
        List<FieldModifiedData> fmd = new List<FieldModifiedData>{
            new FieldModifiedData(envs[0]),
            new FieldModifiedData(envs[1]),
            new FieldModifiedData(envs[2])
        };

        Component__c comp = createComponents(1)[0];
        comp.Field_Modified_Data__c = JSON.serialize(fmd);
        update comp;

        List<Instances__c> instances = [SELECT id FROM Instances__c];
        instances[0].Name = 'env0';
        update instances;

        Test.startTest();
            List<ComponentSearchWrapper> searchWrappers
                = ComponentDocServices.makeComponentSearchWrappers(new List<Component__c>{comp});
        Test.stopTest();

        System.assertEquals(1, searchWrappers.size(),
                            'The correct number of ComponentSearchWrappers should have been returned');

        Set<String> fmdEnvs = new Set<String>(envs);

        Set<String> searchWrapperEnvs = new Set<String>(envs);
        for (ComponentSearchWrapper wrapper : searchWrappers) {
            searchWrapperEnvs.add(wrapper.environment);
        }
        System.assertEquals(fmdEnvs, searchWrapperEnvs, 'The environments should be the same');

        for (ComponentSearchWrapper wrapper : searchWrappers) {
            System.assertEquals(comp.Id, wrapper.component.Id,
                                'The component Ids on the search wrappers should all be the same');
        }
    }

    static testmethod void creatingComponentSearchWrappersFromComps_WithNoFMD() {
        Component__c comp = createComponents(1)[0];

        Test.startTest();
            List<ComponentSearchWrapper> searchWrappers
                = ComponentDocServices.makeComponentSearchWrappers(new List<Component__c>{comp});
        Test.stopTest();

        System.assertEquals(1, searchWrappers.size(),
                            'The correct number of ComponentSearchWrappers should have been returned');

        System.assertEquals(comp.Id, searchWrappers[0].component.Id, 'The Search Wrapper should have the correct Id');
        System.assertEquals(null, searchWrappers[0].lastModifiedDate, 'The lastModifiedDate field should empty');
        System.assert(String.isBlank(searchWrappers[0].environment), 'The environment field should empty');
        System.assert(String.isBlank(searchWrappers[0].lastModifiedBy), 'The lastModifiedBy field should empty');
    }

    static testmethod void creatingComponentSearchWrapperFromComps_CorrectNumberCreated_WithEnvName() {
        
        List<String> instanceNames = new List<String>{'env0', 'env1', 'env2'};

        List<FieldModifiedData> fmdWithDeletedInstance = new List<FieldModifiedData>();
        List<FieldModifiedData> fmdWithNonDeletedInstance = new List<FieldModifiedData>();

        List<Instances__c> instances = new List<Instances__c>();
        for (Integer i = 0; i < instanceNames.size(); i++) {
            
            Instances__c ins = TestingUtils.buildInstance(instanceNames[i]);
            instances.add( ins );

            if (i == 0 || i == 1) {
                ins.Is_Deleted__c = true;
                fmdWithDeletedInstance.add(new FieldModifiedData(instanceNames[i]));
            }
            else{
                fmdWithNonDeletedInstance.add(new FieldModifiedData(instanceNames[i]));
            }
        }
        insert instances;
        

        List<Component__c> allComps = createComponents(4);
        allComps[0].Field_Modified_Data__c = JSON.serialize(fmdWithDeletedInstance);
        allComps[1].Field_Modified_Data__c = JSON.serialize(fmdWithNonDeletedInstance);
        update allComps;
        
        Integer compsWithoutFMD = 2;

        Test.startTest();
            List<ComponentSearchWrapper> searchWrappers = ComponentDocServices.makeComponentSearchWrappers(allComps);
        Test.stopTest();

        System.assertEquals(compsWithoutFMD + fmdWithNonDeletedInstance.size(), searchWrappers.size(),
                            'Search wrappers should only be created for components without FMD and for components whose FMD environmentName matches the Name of its parent instance');

        Set<Id> compIdsWithNonDeletedInstances = new Set<Id>{allComps[1].Id, allComps[2].Id, allComps[3].Id};
        for (ComponentSearchWrapper wrapper: searchWrappers) {
            System.assert(compIdsWithNonDeletedInstances.contains(wrapper.component.ID), 'The correct components should be the ones with search wrappers created for them');
        }
    }

    static testmethod void creatingComponentSearchWrappersFromComps_CorrectNumberCreated_NoEnvNames() {
        List<FieldModifiedData> fmd = new List<FieldModifiedData>{
            new FieldModifiedData('env0'),
            new FieldModifiedData('env1'),
            new FieldModifiedData('env2')
        };

        List<Component__c> allComps = createComponents(4);
        allComps[0].Field_Modified_Data__c = JSON.serialize(new List<FieldModifiedData>{fmd[0], fmd[1]});
        allComps[1].Field_Modified_Data__c = JSON.serialize(new List<FieldModifiedData>{fmd[2]});
        List<Component__c> compsWithFMD = new List<Component__c>{allComps[0], allComps[1]};
        update compsWithFMD;

        List<Component__c> compsWithNoFMD = new List<Component__c>{allComps[2], allComps[3]};

        Test.startTest();
            List<ComponentSearchWrapper> searchWrappers = ComponentDocServices.makeComponentSearchWrappers(allComps);
        Test.stopTest();

        System.assertEquals(compsWithNoFMD.size(), searchWrappers.size(),
                            'If no instance names match the environmentNames of the FMD, only components without FMD should have search wrappers created for them');
    }
}
