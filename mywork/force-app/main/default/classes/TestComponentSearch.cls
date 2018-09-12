@isTest
private class TestComponentSearch {

    static Instances__c instance;
    static Instances__c prodInstance;

    static Component__c componentWithInstanceData1;
    static Component__c componentWithInstanceData2;
    static Component__c componentWithInstanceData7;

    static String USERNAME = 'Target User';

    private static void setup() {
        instance = new Instances__c(Name='dev');
        prodInstance = new Instances__c(Name='prod');
        insert new List<Instances__c>{instance, prodInstance};
        createTestComponents();
    }

    private static void createTestComponents() {
        FieldModifiedData envData1 = new FieldModifiedData( instance.Name,  Datetime.now().addDays(-1), null, null, null);
        FieldModifiedData envData2 = new FieldModifiedData( instance.Name,  Datetime.now(), USERNAME, null, null);

        componentWithInstanceData1 = new Component__c(Name='Test object', Type__c='Object', Instance__c=instance.Id);
        componentWithInstanceData1.Field_Modified_Data__c = JSON.serialize( new List<FieldModifiedData>{ envData1 } );
        componentWithInstanceData2 = new Component__c(Name='Test trigger', Type__c='Trigger', Instance__c=instance.Id);
        componentWithInstanceData2.Field_Modified_Data__c = JSON.serialize( new List<FieldModifiedData>{ envData2 } );
        componentWithInstanceData2.Last_Modified_Users__c = USERNAME;

        Component__c c5 = new Component__c(Name='Test Unit Test', Type__c='Apex Unit Test', Instance__c=instance.Id);
        c5.Field_Modified_Data__c = JSON.serialize( new List<FieldModifiedData>{ envData1 } );
        insert new List<Component__c> { componentWithInstanceData1, componentWithInstanceData2, c5 };

        Component__c c3 = new Component__c(Name='Test custom field 1', Type__c='Object Field', Parent_Component__c=componentWithInstanceData1.Id, Instance__c=instance.Id);
        Component__c c4 = new Component__c(Name='Test custom field 2', Type__c='Object Field', Parent_Component__c=componentWithInstanceData2.Id, Instance__c=instance.Id);
        Component__c c6 = new Component__c(Name='Test custom field 3', Type__c='Apex Unit Test', Parent_Component__c=componentWithInstanceData2.Id, Instance__c=instance.Id);

        insert new List<Component__c> { c3, c4, c6 };
    }

    static testMethod void testToggleSort_Name() {
        setup();
        ComponentSearch compSearch = new ComponentSearch( new Set<String>());

        Test.startTest();
            compSearch.sortField = 'Name';
            compSearch.sortDirection = ComponentSearch.SORT_ORDER_DESC;
            compSearch.toggleSort();
        Test.stopTest();
        System.assertEquals('Test custom field 1', compSearch.currentPage[0].component.Name, 'Components should be sorted by name ascending');
        System.assertEquals('Test custom field 2', compSearch.currentPage[1].component.Name, 'Components should be sorted by name ascending');
        System.assertEquals('Test object', compSearch.currentPage[2].component.Name, 'Components should be sorted by name ascending');
        System.assertEquals('Test trigger', compSearch.currentPage[3].component.Name, 'Components should be sorted by name ascending');

        compSearch.toggleSort();

        System.assertEquals('Test custom field 1', compSearch.currentPage[3].component.Name, 'Components should be sorted by name descending');
        System.assertEquals('Test custom field 2', compSearch.currentPage[2].component.Name, 'Components should be sorted by name descending');
        System.assertEquals('Test object', compSearch.currentPage[1].component.Name, 'Components should be sorted by name descending');
        System.assertEquals('Test trigger', compSearch.currentPage[0].component.Name, 'Components should be sorted by name descending');
    }

    static testMethod void testToggleSort_Type() {
        setup();
        ComponentSearch compSearch = new ComponentSearch( new Set<String>());

        compSearch.sortField = 'Type__c';
        compSearch.sortDirection = ComponentSearch.SORT_ORDER_DESC;

        compSearch.toggleSort(); // results in ascending

        System.assertEquals('Object', compSearch.currentPage[0].component.Type__c);
        System.assertEquals('Object Field', compSearch.currentPage[1].component.Type__c);
        System.assertEquals('Object Field', compSearch.currentPage[2].component.Type__c);
        System.assertEquals('Trigger', compSearch.currentPage[3].component.Type__c);

        compSearch.toggleSort(); // results in descending

        System.assertEquals('Object', compSearch.currentPage[3].component.Type__c);
        System.assertEquals('Object Field', compSearch.currentPage[2].component.Type__c);
        System.assertEquals('Object Field', compSearch.currentPage[1].component.Type__c);
        System.assertEquals('Trigger', compSearch.currentPage[0].component.Type__c);
    }

    static testMethod void testToggleSort_ParentComponent() {
        setup();

        ComponentSearch compSearch = new ComponentSearch( new Set<String>());

        compSearch.sortField = 'Parent_Component__r.Name';
        compSearch.sortDirection = ComponentSearch.SORT_ORDER_DESC;

        compSearch.toggleSort(); // results in ascending

        System.assertEquals('Test object', compSearch.currentPage[0].component.Parent_Component__r.Name);
        System.assertEquals('Test trigger', compSearch.currentPage[1].component.Parent_Component__r.Name);
        System.assertEquals(null, compSearch.currentPage[2].component.Parent_Component__r.Name);
        System.assertEquals(null, compSearch.currentPage[3].component.Parent_Component__r.Name);

        compSearch.toggleSort(); // results in descending

        System.assertEquals('Test trigger', compSearch.currentPage[0].component.Parent_Component__r.Name);
        System.assertEquals('Test object', compSearch.currentPage[1].component.Parent_Component__r.Name);
        System.assertEquals(null, compSearch.currentPage[2].component.Parent_Component__r.Name);
        System.assertEquals(null, compSearch.currentPage[3].component.Parent_Component__r.Name);
    }

    static testMethod void testDoQuery() {
        setup();

        ComponentSearch compSearch = new ComponentSearch( new Set<String>() );

        compSearch.sortField = 'Name';
        compSearch.sortDirection = 'asc';

        Test.startTest();

            compSearch.doQuery();

        Test.stopTest();

        //System.assertEquals(4, compSearch.searchResults.recordCount);
        System.assertEquals(4, compSearch.currentPage.size());
    }

    static testMethod void testDoSearch_Name() {
        setup();

        ComponentSearch compSearch = new ComponentSearch( new Set<String>() );

        compSearch.sortField = 'Name';
        compSearch.sortDirection = 'asc';

        compSearch.doQuery();

        //System.assertEquals(4, compSearch.searchResults.recordCount);
        System.assertEquals(4, compSearch.currentPage.size());

        Test.startTest();
            compSearch.name = 'cus';
            compSearch.cType = '';
            compSearch.parentName = 'tr';

            compSearch.doSearch();
        Test.stopTest();

        //System.assertEquals(1, compSearch.searchResults.recordCount);
        System.assertEquals(1, compSearch.currentPage.size());
        System.assertEquals('Test custom field 2', compSearch.currentPage[0].component.Name);
    }

    static testMethod void testDoSearch_Type() {
        setup();

        ComponentSearch compSearch = new ComponentSearch( new Set<String>() );

        compSearch.sortField = 'Name';
        compSearch.sortDirection = 'asc';

        compSearch.doQuery();

        //System.assertEquals(4, compSearch.searchResults.recordCount);
        System.assertEquals(4, compSearch.currentPage.size());

        Test.startTest();
            compSearch.name = '';
            compSearch.cType = 'ob';
            compSearch.parentName = '';

            compSearch.doSearch();
        Test.stopTest();

        //System.assertEquals(3, compSearch.searchResults.recordCount);
        System.assertEquals(3, compSearch.currentPage.size());
        System.assertEquals('Test custom field 1', compSearch.currentPage[0].component.Name);
        System.assertEquals('Test custom field 2', compSearch.currentPage[1].component.Name);
        System.assertEquals('Test object', compSearch.currentPage[2].component.Name);
    }

    static testMethod void testDoSearch_Instance() {
        Instances__c instance2 = new Instances__c(Name='dev2');
        insert instance2;

        setup();

        Component__c instance2Component = new Component__c(Name='Test object unique instance', Type__c='Object');
        instance2Component.Instance__c = instance2.Id;
        insert instance2Component;

        ComponentSearch compSearch = new ComponentSearch( new Set<String>() );
        compSearch.selectedInstances = instance2.Name;

        Test.startTest();
            compSearch.name = '';
            compSearch.parentName = '';
            compSearch.cType = '';
            compSearch.doSearch();
        Test.stopTest();

        //System.assertEquals(1, compSearch.searchResults.recordCount, 'The component should be matched by instance');
        System.assertEquals(1, compSearch.currentPage.size(), 'The component should be matched by instance');
        System.assertEquals(instance2Component.Name, compSearch.currentPage[0].component.Name, 'The component should be matched by instance');
    }

    static testMethod void testDoSearch_MultipleInstances() {
        Instances__c instance2 = new Instances__c(Name='dev2');
        Instances__c instance3 = new Instances__c(Name='dev3');
        insert new List<Instances__c> {instance2, instance3};

        setup();

        Component__c instance2Component = new Component__c(Name='Test object unique instance', Type__c='Object');
        instance2Component.Instance__c = instance2.Id;
        Component__c instance3Component = new Component__c(Name='Test object unique instance2', Type__c='Object');
        instance3Component.Instance__c = instance3.Id;
        insert new List<Component__c> {instance2Component, instance3Component};

        ComponentSearch compSearch = new ComponentSearch( new Set<String>() );
        compSearch.selectedInstances = instance2.Name + ',' + instance3.Name;

        Test.startTest();
            compSearch.name = '';
            compSearch.parentName = '';
            compSearch.cType = '';
            compSearch.sortField = 'Name';
            compSearch.doSearch();
        Test.stopTest();

        //System.assertEquals(2, compSearch.searchResults.recordCount, 'The components should be matched by instance');
        System.assertEquals(2, compSearch.currentPage.size(), 'The components should be matched by instance');
        System.assertEquals(instance3Component.Name, compSearch.currentPage[0].component.Name, 'The component should be matched by instance');
        System.assertEquals(instance2Component.Name, compSearch.currentPage[1].component.Name, 'The component should be matched by instance');
    }

    static testMethod void testDoSearch_ParentComponent() {
        setup();

        ComponentSearch compSearch = new ComponentSearch( new Set<String>() );

        compSearch.sortField = 'Name';
        compSearch.sortDirection = 'asc';

        compSearch.doQuery();

        //System.assertEquals(4, compSearch.searchResults.recordCount);
        System.assertEquals(4, compSearch.currentPage.size());

        Test.startTest();
            compSearch.name = '';
            compSearch.cType = '';
            compSearch.parentName = 's';

            compSearch.doSearch();
        Test.stopTest();

        //System.assertEquals(2, compSearch.searchResults.recordCount);
        System.assertEquals(2, compSearch.currentPage.size());
        System.assertEquals('Test custom field 1', compSearch.currentPage[0].component.Name);
        System.assertEquals('Test custom field 2', compSearch.currentPage[1].component.Name);
    }

    static testMethod void getSearchResults_filterByUser() {
        setup();

        ComponentSearch compSearch = new ComponentSearch( new Set<String>() );

        Test.startTest();

            compSearch.selectedUsers = new Set<String>{USERNAME};
            compSearch.doSearch();

        Test.stopTest();

         System.assertEquals(1, compSearch.currentPage.size(),
             'The component with matching last modified by user should be returned');
         System.assertEquals(componentWithInstanceData2.Id, compSearch.currentPage[0].component.Id,
             'The component with matching last modified by user should be returned');
    }

    static testMethod void testDoSearch_AllFilters() {
        setup();

        ComponentSearch compSearch = new ComponentSearch( new Set<String>() );

        compSearch.sortField = 'Name';
        compSearch.sortDirection = 'asc';

        compSearch.doQuery();

        //System.assertEquals(4, compSearch.searchResults.recordCount);
        System.assertEquals(4, compSearch.currentPage.size());

        Test.startTest();
            compSearch.name = '1';
            compSearch.cType = 'f';
            compSearch.parentName = 't';

            compSearch.doSearch();
        Test.stopTest();

        //System.assertEquals(1, compSearch.searchResults.recordCount);
        System.assertEquals(1, compSearch.currentPage.size());
        System.assertEquals('Test custom field 1', compSearch.currentPage[0].component.Name);
    }

    static testMethod void getSelectedComponents() {
        setup();

        ComponentSearchWrapper selectedComponent1 = new ComponentSearchWrapper( componentWithInstanceData1, instance.Name, '', null, '', false );

        String selectedComponentKeys = selectedComponent1.getKey();
        System.debug(selectedComponentKeys);

        Test.startTest();

            List<ComponentSearchWrapper> results = ComponentSearch.getSelectedComponents(selectedComponentKeys);

        Test.stopTest();

        System.assertEquals(1, results.size(), 'Only the selected component should be returned');
        System.assertEquals(selectedComponent1.getKey(), results[0].getKey(), 'The selected component should be returned');
    }

    static testMethod void getSelectedComponents_multiple() {
        setup();

        ComponentSearchWrapper selectedComponent1 = new ComponentSearchWrapper(componentWithInstanceData1, instance.Name, '', null, '', false);
        ComponentSearchWrapper selectedComponent2 = new ComponentSearchWrapper(componentWithInstanceData2, instance.Name, '', null, '', false);


        String selectedComponentKeys = selectedComponent1.getKey() + ',' + selectedComponent2.getKey();

        Test.startTest();

            List<ComponentSearchWrapper> results = ComponentSearch.getSelectedComponents(selectedComponentKeys);

        Test.stopTest();

        Set<String> componentKeys = new Set<String> {
            selectedComponent1.getKey(),
            selectedComponent2.getKey()
        };

        System.assertEquals(2, results.size(), 'Both selected components should be returned');

        for(ComponentSearchWrapper component : results) {
            System.assert(componentKeys.contains(component.getKey()), 'Both selected components should be returned');
        }
    }

    static testMethod void getSelectedComponents_Deleted() {
        setup();

        Component__c nonDeletedComponent = new Component__c(Name='Test Profile', Type__c='Profile', Instance__c=instance.Id, Deleted__c=false);
        Component__c deletedComponent = new Component__c(Name='Test Class', Type__c='Apex Class', Instance__c=instance.Id, Deleted__c=true);
        insert new List<Component__c> {nonDeletedComponent, deletedComponent};

        ComponentSearchWrapper selectedComponentNonDeleted = new ComponentSearchWrapper(nonDeletedComponent, instance.Name, '', null, '', false);
        ComponentSearchWrapper selectedComponentDeleted = new ComponentSearchWrapper(deletedComponent, instance.Name, '', null, '', false);

        String selectedComponentKeys = selectedComponentNonDeleted.getKey() + ',' + selectedComponentDeleted.getKey();

        Test.startTest();

            List<ComponentSearchWrapper> results = ComponentSearch.getSelectedComponents(selectedComponentKeys);

        Test.stopTest();

        Set<String> componentKeys = new Set<String> {
            selectedComponentNonDeleted.getKey(),
            selectedComponentDeleted.getKey()
        };

        System.assertEquals(2, results.size(), 'Both selected components should be returned');

        for(ComponentSearchWrapper component : results) {
            System.assert(componentKeys.contains(component.getKey()), 'Both selected components should be returned');
        }
    }

    static testMethod void testDoSearch_includeProfiles() {
        Instances__c instance = TestingUtils.createInstance('profile instance');
        Component__c profileComponent = TestingUtils.createComponent('ProfileToInclude', ComponentDocServices.PROFILE_COMPONENT_TYPE, instance.Id);
        
        ComponentSearch compSearch = new ComponentSearch( new Set<String>() );
        Test.startTest();
            compSearch.doSearch();
        Test.stopTest();

        System.assertEquals(1, compSearch.currentPage.size(), 'The profile component should be returned');
        System.assertEquals(profileComponent.Name, compSearch.currentPage[0].component.Name,
             'The profile component should be returned when include profiles is not set');
    }

    static testMethod void testDoSearch_excludeProfiles() {
        Instances__c instance = TestingUtils.createInstance('profile instance');
        Component__c profileComponent = TestingUtils.createComponent('ProfileToExclude', ComponentDocServices.PROFILE_COMPONENT_TYPE, instance.Id);
        
        ComponentSearch compSearch = new ComponentSearch( new Set<String>() );
        compSearch.includeProfiles = false;
        Test.startTest();
            compSearch.doSearch();
        Test.stopTest();

        System.assertEquals(0, compSearch.currentPage.size(),
             'The profile component should be excluded when include profiles is set to false');
    }

    static testMethod void testDoSearch_WithOffsetFirstPage() {
        setup();

        ComponentSearch compSearch = new ComponentSearch( new Set<String>() );

        compSearch.sortField = 'Name';
        compSearch.sortDirection = 'asc';

        compSearch.doQuery();
        System.assertEquals(4, compSearch.currentPage.size());

        Test.startTest();
            compSearch.name = '';
            compSearch.cType = 'ob';
            compSearch.parentName = '';
            compSearch.requestedPageNumber = 1;
            compSearch.maxResultSize = 1;

            compSearch.doSearch();
        Test.stopTest();

        System.assertEquals(1, compSearch.currentPage.size());
        System.assertEquals('Test custom field 1', compSearch.currentPage[0].component.Name);
    }

    static testMethod void testDoSearch_WithOffsetSecondPage() {
        setup();

        ComponentSearch compSearch = new ComponentSearch( new Set<String>() );

        compSearch.sortField = 'Name';
        compSearch.sortDirection = 'asc';

        compSearch.doQuery();

        System.assertEquals(4, compSearch.currentPage.size());

        Test.startTest();
            compSearch.name = '';
            compSearch.cType = 'ob';
            compSearch.parentName = '';
            compSearch.requestedPageNumber = 2;
            compSearch.maxResultSize = 1;

            compSearch.doSearch();
        Test.stopTest();

        System.assertEquals(1, compSearch.currentPage.size());
        System.assertEquals('Test custom field 2', compSearch.currentPage[0].component.Name);
    }

    static testMethod void testDoSearch_WithOffsetThirdPage() {
        setup();

        ComponentSearch compSearch = new ComponentSearch( new Set<String>() );

        compSearch.sortField = 'Name';
        compSearch.sortDirection = 'asc';

        compSearch.doQuery();

        System.assertEquals(4, compSearch.currentPage.size());

        Test.startTest();
            compSearch.name = '';
            compSearch.cType = 'ob';
            compSearch.parentName = '';
            compSearch.requestedPageNumber = 3;
            compSearch.maxResultSize = 1;

            compSearch.doSearch();
        Test.stopTest();

        System.assertEquals(1, compSearch.currentPage.size());
        System.assertEquals('Test object', compSearch.currentPage[0].component.Name);
    }

    static testMethod void testDoSearch_WithOffsetFirstPage_PageSizeTwo() {
        setup();

        ComponentSearch compSearch = new ComponentSearch( new Set<String>() );

        compSearch.sortField = 'Name';
        compSearch.sortDirection = 'asc';

        compSearch.doQuery();

        System.assertEquals(4, compSearch.currentPage.size());

        Test.startTest();
            compSearch.name = '';
            compSearch.cType = 'ob';
            compSearch.parentName = '';
            compSearch.requestedPageNumber = 1;
            compSearch.maxResultSize = 2;

            compSearch.doSearch();
        Test.stopTest();

        System.assertEquals(2, compSearch.currentPage.size());
        System.assertEquals('Test custom field 1', compSearch.currentPage[0].component.Name);
        System.assertEquals('Test custom field 2', compSearch.currentPage[1].component.Name);
    }

    static testMethod void testDoSearch_ExpandAllComponentSearchWrappersWhenPaginating() {
        setup();

        String COMPONENT_NAME = 'prod_page';

        FieldModifiedData envData2 = new FieldModifiedData( instance.Name,  Datetime.now(), null, null, null);
        FieldModifiedData envData3 = new FieldModifiedData( prodInstance.Name,  Datetime.now(), null, null, null);
        componentWithInstanceData7 = new Component__c(Name=COMPONENT_NAME, Type__c='Visualforce Page', Instance__c=prodInstance.Id);
        componentWithInstanceData7.Field_Modified_Data__c = JSON.serialize( new List<FieldModifiedData>{ envData2, envData3 } );
        insert componentWithInstanceData7;

        ComponentSearch compSearch = new ComponentSearch( new Set<String>() );

        Test.startTest();
            compSearch.name = '';
            compSearch.cType = 'Visualforce Page';
            compSearch.parentName = '';
            compSearch.requestedPageNumber = 1;
            compSearch.maxResultSize = 1; // should not limit the number of component search wrappers we get back
                                          // when multiple instances on one component
            compSearch.doSearch();
        Test.stopTest(); //

        System.assertEquals(2, compSearch.currentPage.size());
        System.assertEquals(COMPONENT_NAME, compSearch.currentPage[0].component.Name);
        System.assertEquals(COMPONENT_NAME, compSearch.currentPage[1].component.Name);
        System.assertEquals(componentWithInstanceData7.Id, compSearch.currentPage[0].component.Id);
        System.assertEquals(componentWithInstanceData7.Id, compSearch.currentPage[1].component.Id);
        Set<String> environmentsOnWrappers = new Set<String>{compSearch.currentPage[0].environment, compSearch.currentPage[1].environment};
        System.assertEquals(new Set<String>{instance.Name, prodInstance.Name}, environmentsOnWrappers,
            'We expect the environments to be correct on the component search wrappers.');
    }

    static testMethod void testDoSearch_LimitComponentSearchWrappers() {
        setup();

        String COMPONENT_NAME = 'prod_page';

        FieldModifiedData envData2 = new FieldModifiedData( instance.Name,  Datetime.now(), null, null, null);
        FieldModifiedData envData3 = new FieldModifiedData( prodInstance.Name,  Datetime.now(), null, null, null);
        componentWithInstanceData7 = new Component__c(Name=COMPONENT_NAME, Type__c='Visualforce Page', Instance__c=prodInstance.Id);
        componentWithInstanceData7.Field_Modified_Data__c = JSON.serialize( new List<FieldModifiedData>{ envData2, envData3 } );
        insert componentWithInstanceData7;

        ComponentSearch compSearch = new ComponentSearch( new Set<String>() );

        Test.startTest();
            compSearch.name = '';
            compSearch.cType = 'Visualforce Page';
            compSearch.parentName = '';
            compSearch.maxResultSize = 1; // should limit the number of component search wrappers we get back
            compSearch.doSearch();
        Test.stopTest(); //

        System.assertEquals(1, compSearch.currentPage.size());
        System.assertEquals(COMPONENT_NAME, compSearch.currentPage[0].component.Name);
        System.assertEquals(componentWithInstanceData7.Id, compSearch.currentPage[0].component.Id);
        System.assertEquals(instance.Name, compSearch.currentPage[0].environment,
            'We expect the environment to be correct on the component search wrappers.');
    }

    static testMethod void testDoSearch_WithOffsetSecondPage_PageSizeTwo() {
        setup();

        ComponentSearch compSearch = new ComponentSearch( new Set<String>() );

        compSearch.sortField = 'Name';
        compSearch.sortDirection = 'asc';

        compSearch.doQuery();

        System.assertEquals(4, compSearch.currentPage.size());

        Test.startTest();
            compSearch.name = '';
            compSearch.cType = 'ob';
            compSearch.parentName = '';
            compSearch.requestedPageNumber = 2;
            compSearch.maxResultSize = 2;

            compSearch.doSearch();
        Test.stopTest();

        System.assertEquals(1, compSearch.currentPage.size());
        System.assertEquals('Test object', compSearch.currentPage[0].component.Name);
    }

    static testMethod void testDoSearch_WithOffsetFourthPage_ExpectEmpty() {
        setup();

        ComponentSearch compSearch = new ComponentSearch( new Set<String>() );

        compSearch.sortField = 'Name';
        compSearch.sortDirection = 'asc';

        compSearch.doQuery();

        System.assertEquals(4, compSearch.currentPage.size());

        Test.startTest();
            compSearch.name = '';
            compSearch.cType = 'ob';
            compSearch.parentName = '';
            compSearch.requestedPageNumber = 4;
            compSearch.maxResultSize = 1;

            compSearch.doSearch();
        Test.stopTest();

        System.assertEquals(0, compSearch.currentPage.size());
    }

}