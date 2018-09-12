@isTest
private class TestComponentSearchController {
    /**--------------------------------------- DEPRECATED CLASS ---------------------------------------
    static ComponentSearchController controller;

    private static void createTestComponents() {
        controller = new ComponentSearchController();

        Component__c c1 = new Component__c(Name='Test object', Type__c='Apex Class');
        insert c1;

        Component__c c2 = new Component__c(Name='Test Apex Trigger', Type__c='Apex Trigger');
        Component__c c3 = new Component__c(Name='Test custom field 1', Type__c='Apex Unit Test', Parent_Component__c=c1.Id);
        Component__c c4 = new Component__c(Name='Test custom field 2', Type__c='Apex Unit Test', Parent_Component__c=c1.Id);
        Component__c[] components = new Component__c[] {c2, c3, c4};
        insert components;
    }

    static testMethod void testToggleSort_Name() {
        createTestComponents();

        controller.sortField = 'Name';
        controller.sortDirection = 'desc';

        controller.toggleSort(); // results in ascending

        System.assertEquals('Test custom field 1', controller.searchResultsWrapper.get(0).component.Name);
        System.assertEquals('Test custom field 2', controller.searchResultsWrapper.get(1).component.Name);
        System.assertEquals('Test object', controller.searchResultsWrapper.get(2).component.Name);
        System.assertEquals('Test Apex Trigger', controller.searchResultsWrapper.get(3).component.Name);

        controller.toggleSort(); // results in descending

        System.assertEquals('Test custom field 1', controller.searchResultsWrapper.get(3).component.Name);
        System.assertEquals('Test custom field 2', controller.searchResultsWrapper.get(2).component.Name);
        System.assertEquals('Test object', controller.searchResultsWrapper.get(1).component.Name);
        System.assertEquals('Test Apex Trigger', controller.searchResultsWrapper.get(0).component.Name);
    }

    static testMethod void testToggleSort_Type() {
        createTestComponents();

        controller.sortField = 'Type__c';
        controller.sortDirection = 'desc';

        controller.toggleSort(); // results in ascending

        System.assertEquals('Object', controller.searchResultsWrapper.get(0).component.Type__c);
        System.assertEquals('Object Field', controller.searchResultsWrapper.get(1).component.Type__c);
        System.assertEquals('Object Field', controller.searchResultsWrapper.get(2).component.Type__c);
        System.assertEquals('Apex Trigger', controller.searchResultsWrapper.get(3).component.Type__c);

        controller.toggleSort(); // results in descending

        System.assertEquals('Object', controller.searchResultsWrapper.get(3).component.Type__c);
        System.assertEquals('Object Field', controller.searchResultsWrapper.get(2).component.Type__c);
        System.assertEquals('Object Field', controller.searchResultsWrapper.get(1).component.Type__c);
        System.assertEquals('Apex Trigger', controller.searchResultsWrapper.get(0).component.Type__c);
    }

    static testMethod void testToggleSort_ParentComponent() {
        createTestComponents();

        controller.sortField = 'Parent_Component__r.Name';
        controller.sortDirection = 'desc';

        controller.toggleSort(); // results in ascending

        System.assertEquals(null, controller.searchResultsWrapper.get(0).component.Parent_Component__r.Name);
        System.assertEquals(null, controller.searchResultsWrapper.get(1).component.Parent_Component__r.Name);
        System.assertEquals('Test object', controller.searchResultsWrapper.get(2).component.Parent_Component__r.Name);
        System.assertEquals('Test object', controller.searchResultsWrapper.get(3).component.Parent_Component__r.Name);

        controller.toggleSort(); // results in descending

        System.assertEquals(null, controller.searchResultsWrapper.get(0).component.Parent_Component__r.Name);
        System.assertEquals(null, controller.searchResultsWrapper.get(1).component.Parent_Component__r.Name);
        System.assertEquals('Test object', controller.searchResultsWrapper.get(2).component.Parent_Component__r.Name);
        System.assertEquals('Test object', controller.searchResultsWrapper.get(3).component.Parent_Component__r.Name);
    }

    static testMethod void testDoQuery() {
        createTestComponents();

        controller.sortField = 'Name';
        controller.sortDirection = 'asc';

        controller.doQuery();

        System.assertEquals(4, controller.recordCount);
        System.assertEquals(4, controller.searchResultsWrapper.size());
    }

    static testMethod void testDoSearch_Name() {
        createTestComponents();

        controller.sortField = 'Name';
        controller.sortDirection = 'asc';

        controller.doQuery();

        System.assertEquals(4, controller.recordCount);
        System.assertEquals(4, controller.searchResultsWrapper.size());

        PageReference p = Page.AssetEntry;
        Test.setCurrentPage(p);

        ApexPages.currentPage().getParameters().put('name', 'tr');
        ApexPages.currentPage().getParameters().put('type', '');
        ApexPages.currentPage().getParameters().put('parentName', '');
        ApexPages.currentPage().getParameters().put('includeDeleted', 'false');

        controller.doSearch();
        System.assertEquals(1, controller.recordCount);
        System.assertEquals(1, controller.searchResultsWrapper.size());
        System.assertEquals('Test Apex Trigger', controller.searchResultsWrapper.get(0).component.Name);
    }

    static testMethod void testDoSearch_Type() {
        createTestComponents();

        controller.sortField = 'Name';
        controller.sortDirection = 'asc';

        controller.doQuery();

        System.assertEquals(4, controller.recordCount);
        System.assertEquals(4, controller.searchResultsWrapper.size());

        PageReference p = Page.AssetEntry;
        Test.setCurrentPage(p);

        ApexPages.currentPage().getParameters().put('name', '');
        ApexPages.currentPage().getParameters().put('type', 'ob');
        ApexPages.currentPage().getParameters().put('parentName', '');
        ApexPages.currentPage().getParameters().put('includeDeleted', 'false');

        controller.doSearch();
        System.assertEquals(3, controller.recordCount);
        System.assertEquals(3, controller.searchResultsWrapper.size());
        System.assertEquals('Test custom field 1', controller.searchResultsWrapper.get(0).component.Name);
        System.assertEquals('Test custom field 2', controller.searchResultsWrapper.get(1).component.Name);
        System.assertEquals('Test object', controller.searchResultsWrapper.get(2).component.Name);
    }

    static testMethod void testDoSearch_ParentComponent() {
        createTestComponents();

        controller.sortField = 'Name';
        controller.sortDirection = 'asc';

        controller.doQuery();

        System.assertEquals(4, controller.recordCount);
        System.assertEquals(4, controller.searchResultsWrapper.size());

        PageReference p = Page.AssetEntry;
        Test.setCurrentPage(p);

        ApexPages.currentPage().getParameters().put('name', '');
        ApexPages.currentPage().getParameters().put('type', '');
        ApexPages.currentPage().getParameters().put('parentName', 's');
        ApexPages.currentPage().getParameters().put('includeDeleted', 'false');

        controller.doSearch();
        System.assertEquals(2, controller.recordCount);
        System.assertEquals(2, controller.searchResultsWrapper.size());
        System.assertEquals('Test custom field 1', controller.searchResultsWrapper.get(0).component.Name);
        System.assertEquals('Test custom field 2', controller.searchResultsWrapper.get(1).component.Name);
    }

    static testMethod void testDoSearch_AllFilters() {
        createTestComponents();

        controller.sortField = 'Name';
        controller.sortDirection = 'asc';

        controller.doQuery();

        System.assertEquals(4, controller.recordCount);
        System.assertEquals(4, controller.searchResultsWrapper.size());

        PageReference p = Page.AssetEntry;
        Test.setCurrentPage(p);

        ApexPages.currentPage().getParameters().put('name', '1');
        ApexPages.currentPage().getParameters().put('type', 'f');
        ApexPages.currentPage().getParameters().put('parentName', 't');
        ApexPages.currentPage().getParameters().put('includeDeleted', 'false');

        controller.doSearch();
        System.assertEquals(1, controller.recordCount);
        System.assertEquals(1, controller.searchResultsWrapper.size());
        System.assertEquals('Test custom field 1', controller.searchResultsWrapper.get(0).component.Name);
    }

    static testMethod void testUpdateSearchResultsCheckboxes() {
        createTestComponents();

        controller.sortField = 'Name';
        controller.sortDirection = 'asc';

        controller.doQuery();

        PageReference p = Page.AssetEntry;
        Test.setCurrentPage(p);

        ApexPages.currentPage().getParameters().put('selectAll', 'true');
        controller.updateSearchResultsCheckboxes();

        for (ComponentSearchWrapper w : controller.searchResultsWrapper) {
            System.assert(w.checked == true);
        }

        ApexPages.currentPage().getParameters().put('selectAll', 'false');
        controller.updateSearchResultsCheckboxes();

        for (ComponentSearchWrapper w : controller.searchResultsWrapper) {
            System.assert(w.checked == false);
        }
    }
*/
    /*
    static testMethod void testUpdateSavedComponentsCheckboxes() {
        createTestComponents();

        controller.sortField = 'Name';
        controller.sortDirection = 'asc';

        controller.doQuery();

        PageReference p = Page.AssetEntry;
        Test.setCurrentPage(p);

        ApexPages.currentPage().getParameters().put('selectAll', 'true');
        controller.updateSavedComponentsCheckboxes();

        for (ComponentSearchWrapper w : controller.existingSavedMembers) {
            System.assert(w.checked == true);
        }

        ApexPages.currentPage().getParameters().put('selectAll', 'false');
        controller.updateSavedComponentsCheckboxes();

        for (ComponentSearchWrapper w : controller.existingSavedMembers) {
            System.assert(w.checked == false);
        }
    }
   */
}