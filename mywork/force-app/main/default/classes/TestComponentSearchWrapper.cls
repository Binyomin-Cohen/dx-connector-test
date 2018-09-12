@isTest
private class TestComponentSearchWrapper {

    static testMethod void constructor_noBacklogComponent() {
        String testName = 'Test Component Name';
        String testType = 'Test Component Type';
        String testFieldModifiedData = 'Test Component Field Modified Data';
        String testEnvironment = 'Test Environment';
        String testNotes = 'Test Notes';
        DateTime testLastModifiedDate = DateTime.now();
        String testLastModifiedBy = 'Test Last Modified By';

        Component__c comp = new Component__c(Name=testName, Type__c=testType, Field_Modified_Data__c=testFieldModifiedData);
        insert comp;

        Test.startTest();

            ComponentSearchWrapper wrapper = new ComponentSearchWrapper(comp, testEnvironment, testNotes, testLastModifiedDate, testLastModifiedBy, false);

        Test.stopTest();

        System.assertEquals(comp.Id, wrapper.component.Id, 'The ID should match.');
        System.assertEquals(testName, wrapper.componentName, 'The name should match.');
        System.assertEquals(testEnvironment + '|' + comp.Id, wrapper.key, 'The key should match.');
        System.assertEquals(testEnvironment, wrapper.environment, 'The environment should match.');
        System.assertEquals(testNotes, wrapper.notes, 'The note should match.');
        System.assertEquals(testLastModifiedDate, wrapper.lastModifiedDate, 'The last modified date should match.');
        System.assertEquals(testLastModifiedBy, wrapper.lastModifiedBy, 'The last modified by should match.');
        System.assertEquals(false, wrapper.isUnsupportedType, 'The type should be supported.');
        System.assertEquals(false, wrapper.existsOnCurrentBacklog, 'The wrapper should not exist on the current backlog.');
        System.assertEquals(false, wrapper.checked, 'The wrapper should not be checked.');
        System.assertEquals(null, wrapper.component.Field_Modified_Data__c, 'The component field modified data should be null.');
    }

    static testMethod void constructor_noBacklogComponent_isDeleted() {
        Boolean testDeleted = true;

        Component__c comp = new Component__c(Name='Test Component Name', Type__c='Test Component Type', Field_Modified_Data__c='Test Component Field Modified Data');
        insert comp;

        Test.startTest();

            ComponentSearchWrapper wrapper = new ComponentSearchWrapper(comp, 'Test Environment', 'Test Notes', DateTime.now(), 'Test Last Modified By', testDeleted);

        Test.stopTest();


        System.assertEquals(true, wrapper.isDeleted, 'The component should be marked as deleted.');
    }

    static testMethod void constructor_withBacklogComponent() {
        String testName = 'Test Component Name';
        String testType = 'Test Component Type';
        String testFieldModifiedData = 'Test Component Field Modified Data';
        String testEnvironment = 'Test Environment';
        String testNotes = 'Test Notes';
        DateTime testLastModifiedDate = DateTime.now();
        String testLastModifiedBy = 'Test Last Modified By';

        Component__c comp = new Component__c(Name=testName, Type__c=testType, Field_Modified_Data__c=testFieldModifiedData);
        insert comp;
        Backlog__c backlog = new Backlog__c();
        insert backlog;
        Backlog_Component__c backlogComp = new Backlog_Component__c(Source_Sandbox__c=testEnvironment, Notes__c=testNotes, Component__c=comp.Id, Component__r=comp, Backlog__c=backlog.Id);
        insert backlogComp;

        Test.startTest();

            ComponentSearchWrapper wrapper = new ComponentSearchWrapper(comp, backlogComp, testLastModifiedDate, testLastModifiedBy, false);

        Test.stopTest();

        System.assertEquals(comp.Id, wrapper.component.Id, 'The ID should match.');
        System.assertEquals(testName, wrapper.componentName, 'The name should match.');
        System.assertEquals(testEnvironment, wrapper.environment, 'The environment should match.');
        System.assertEquals(testNotes, wrapper.notes, 'The note should match.');
        System.assertEquals(testLastModifiedDate, wrapper.lastModifiedDate, 'The last modified date should match.');
        System.assertEquals(testLastModifiedBy, wrapper.lastModifiedBy, 'The last modified by should match.');
        System.assertEquals(false, wrapper.isUnsupportedType, 'The type should be supported.');
        System.assertEquals(false, wrapper.existsOnCurrentBacklog, 'The wrapper should not exist on the current backlog.');
        System.assertEquals(false, wrapper.checked, 'The wrapper should not be checked.');
        System.assertEquals(null, wrapper.component.Field_Modified_Data__c, 'The component field modified data should be null.');
        System.assertEquals(null, wrapper.backlogComponent.Component__r, 'The component relationship on the backlog component should be null.');
    }

    static testMethod void constructor_backlogComponent_isDeleted() {
        Boolean testDeleted = true;

        Component__c comp = new Component__c(Name='Test Component Name', Type__c='Test Component Type', Field_Modified_Data__c='Test Component Field Modified Data');
        insert comp;
        Backlog__c backlog = new Backlog__c();
        insert backlog;
        Backlog_Component__c backlogComp = new Backlog_Component__c(Source_Sandbox__c='Test Environment', Notes__c='Test Notes', Component__c=comp.Id, Component__r=comp, Backlog__c=backlog.Id);
        insert backlogComp;

        Test.startTest();

            ComponentSearchWrapper wrapper = new ComponentSearchWrapper(comp, backlogComp, DateTime.now(), 'Test Last Modified By', testDeleted);

        Test.stopTest();

        System.assertEquals(true, wrapper.isDeleted, 'The component should be marked as deleted.');
    }

    static testMethod void constructor_backlogComponent_withFMD() {
        DateTime createdDate = DateTime.now();
        DateTime lastModifiedDate = DateTime.now().addMinutes(1);


        FieldModifiedData fmd = new FieldModifiedData('environmentName', lastModifiedDate, 'lastModifiedByName',
                                                        createdDate,  'createdByName', false);

        Component__c comp = new Component__c(Name='component');
        insert comp;

        Test.startTest();
            ComponentSearchWrapper csw = new ComponentSearchWrapper(comp, fmd);
        Test.stopTest();

        System.assertEquals(comp.Id, csw.component.Id, 'The Id should match');
        System.assertEquals(fmd.environmentName, csw.environment, 'The environmentName should match');
        System.assertEquals(fmd.lastModifiedDate, csw.lastModifiedDate, 'The lastModifiedDate should match');
        System.assertEquals(fmd.lastModifiedByName, csw.lastModifiedBy, 'The lastModifiedByName should match');
        System.assertEquals(fmd.deleted, csw.isDeleted, 'The deleted field should match');
        System.assert(String.isBlank(csw.notes), 'The notes should be blank');

        System.assertEquals(false, csw.existsOnCurrentBacklog, 'The wrapper should not exist on the current backlog.');
        System.assertEquals(false, csw.checked, 'The wrapper should not be checked.');
    }

    static testMethod void testIsUnsupportedType() {
        // Put a record into the custom setting
        UnsupportedMetadataTypes__c rec = new UnsupportedMetadataTypes__c();
        rec.Name = 'Foo';
        rec.Name__c = 'Foo';
        insert rec;

        Integer actual = ComponentSearchWrapper.unsupportedTypesList.size();
        System.assertEquals(1, actual, 'Expected size of Custom Setting to be 1');
    }

    static testMethod void testIsUnsupportedType_deployManuallyTrue() {
        final String UNSUPPORTED_TYPE = 'Test Component Type';
        String testName = 'Test Component Name';
        String testFieldModifiedData = 'Test Component Field Modified Data';
        String testEnvironment = 'Test Environment';
        String testNotes = 'Test Notes';
        DateTime testLastModifiedDate = DateTime.now();
        String testLastModifiedBy = 'Test Last Modified By';

        // Put a record into the custom setting
        UnsupportedMetadataTypes__c rec = new UnsupportedMetadataTypes__c();
        rec.Name = UNSUPPORTED_TYPE;
        rec.Name__c = UNSUPPORTED_TYPE;
        insert rec;

        Component__c comp = new Component__c(Name=testName, Type__c=UNSUPPORTED_TYPE, Field_Modified_Data__c=testFieldModifiedData);
        insert comp;

        Test.startTest();

            ComponentSearchWrapper wrapper = new ComponentSearchWrapper(comp, testEnvironment, testNotes, testLastModifiedDate, testLastModifiedBy, false);

        Test.stopTest();

        System.assertEquals(true, wrapper.isUnsupportedType, 'The unsupported attribute on the wrapper should be set to true');
        System.assertEquals(true, wrapper.deployManually, 'The deploymanually attribute on the wrapper should be set to true');
    }

    static testMethod void testIsUnsupportedType_deployManuallyFalse() {
        final String SUPPORTED_TYPE = 'Test Component Type supported';
        final String UNSUPPORTED_TYPE = 'Test Component Type';
        String testName = 'Test Component Name';
        String testFieldModifiedData = 'Test Component Field Modified Data';
        String testEnvironment = 'Test Environment';
        String testNotes = 'Test Notes';
        DateTime testLastModifiedDate = DateTime.now();
        String testLastModifiedBy = 'Test Last Modified By';

        // Put a record into the custom setting
        UnsupportedMetadataTypes__c rec = new UnsupportedMetadataTypes__c();
        rec.Name = UNSUPPORTED_TYPE;
        rec.Name__c = UNSUPPORTED_TYPE;
        insert rec;

        Component__c comp = new Component__c(Name=testName, Type__c=SUPPORTED_TYPE, Field_Modified_Data__c=testFieldModifiedData);
        insert comp;

        Test.startTest();

            ComponentSearchWrapper wrapper = new ComponentSearchWrapper(comp, testEnvironment, testNotes, testLastModifiedDate, testLastModifiedBy, false);

        Test.stopTest();

        System.assertEquals(false, wrapper.isUnsupportedType, 'The unsupported attribute on the wrapper should be set to false');
        System.assertEquals(false, wrapper.deployManually, 'The deploymanually attribute on the wrapper should be set to false');
    }

    static testMethod void testAddWrapper() {
        Component__c c = new Component__c(Name='Foo', Type__c='Apex Class');
        insert c;

        List<ComponentSearchWrapper> wrapperList = new List<ComponentSearchWrapper>();

        ComponentSearchWrapper.addWrapper(wrapperList, c, '', '', null, '', false);

        System.assertEquals(1, wrapperList.size(), 'Expected size of list to be 1');
    }

    static testMethod void testAddWrapper_wrapperHasRequiredAttrs() {
        Component__c parent = new Component__c(Name='parent', Type__c='Object');
        insert parent;
        Component__c comp = new Component__c(Name='comp', Type__c='Field', Parent_Component__r=parent);
        insert comp;

        List<ComponentSearchWrapper> wrapperList = new List<ComponentSearchWrapper>();
        Test.startTest();
            ComponentSearchWrapper.addWrapper(wrapperList, comp, '', '', null, '', false);
        Test.stopTest();

        ComponentSearchWrapper wrapper = wrapperList[0];
        System.debug(wrapper);
        System.assertEquals(comp.Type__c, wrapper.componentType, 'Type should be set on the wrapper');
        System.assertEquals(parent.Name, wrapper.parentComponentName, 'Parent component name should be set on the wrapper');
        System.assertEquals(parent.Id, wrapper.parentComponentId, 'Id should be set on the wrapper');
    }

    static testMethod void testCompareTo() {
        Component__c c = new Component__c(Name='Foo', Type__c='Apex Class');
        insert c;

        List<ComponentSearchWrapper> wrapperList = new List<ComponentSearchWrapper>();
        wrapperList.add(new ComponentSearchWrapper(c, 'prod', '', DateTime.newInstance(2014, 1, 31, 8, 30, 0), 'Bryan', false));
        wrapperList.add(new ComponentSearchWrapper(c, 'dev', '', DateTime.newInstance(2014, 1, 31, 14, 30, 0), 'Bryan', false));
        wrapperList.add(new ComponentSearchWrapper(c, 'qa', '', DateTime.newInstance(2014, 12, 31, 14, 30, 0), 'Bryan', false));

        Test.startTest();

            wrapperList.sort();

        Test.stopTest();

        System.assertEquals('qa', wrapperList[0].environment, 'Should be first sorted item with date of 12/31/2014 02:30 PM');
        System.assertEquals('dev', wrapperList[1].environment, 'Should be second sorted item with date of 01/31/2014 02:30 PM');
        System.assertEquals('prod', wrapperList[2].environment, 'Should be third sorted item with date of 01/31/2014 08:30 AM');
    }

    static testMethod void testCompareTo_nullDates() {
        Component__c c = new Component__c(Name='Foo', Type__c='Apex Class');
        insert c;

        List<ComponentSearchWrapper> wrapperList = new List<ComponentSearchWrapper>();
        wrapperList.add(new ComponentSearchWrapper(c, 'prod', '', DateTime.newInstance(2014, 1, 31, 8, 30, 0), 'Bryan', false));
        wrapperList.add(new ComponentSearchWrapper(c, 'dev', '', null, 'Chris', false));
        wrapperList.add(new ComponentSearchWrapper(c, 'qa', '', null, 'Doug', false));
        wrapperList.add(new ComponentSearchWrapper(c, 'int', '', DateTime.newInstance(2014, 12, 31, 14, 30, 0), 'Ethan', false));

        Test.startTest();

            wrapperList.sort();

        Test.stopTest();

        System.assertEquals('int', wrapperList[0].environment, 'The component with the latest date should be sorted first');
        System.assertEquals('prod', wrapperList[1].environment, 'Components should be sorted by last modified date');
        System.assertEquals(null, wrapperList[2].lastModifiedDate, 'Components  with null dates should be sorted last');
        System.assertEquals(null, wrapperList[3].lastModifiedDate, 'Components  with null dates should be sorted last');
    }

    static testMethod void testCompareTo_nullDates_asc() {
        Component__c c = new Component__c(Name='Foo', Type__c='Apex Class');
        insert c;


        List<ComponentSearchWrapper> wrapperList = new List<ComponentSearchWrapper>();
        wrapperList.add(new ComponentSearchWrapper(c, 'prod', '', DateTime.newInstance(2014, 1, 31, 8, 30, 0), 'Bryan', false));
        wrapperList.add(new ComponentSearchWrapper(c, 'dev', '', null, 'Chris', false));
        wrapperList.add(new ComponentSearchWrapper(c, 'qa', '', null, 'Doug', false));
        wrapperList.add(new ComponentSearchWrapper(c, 'int', '', DateTime.newInstance(2014, 12, 31, 14, 30, 0), 'Ethan', false));

        Test.startTest();

            ComponentSearchWrapper.sortDescending = false;
            wrapperList.sort();

        Test.stopTest();

        System.assertEquals(null, wrapperList[0].lastModifiedDate, 'Components with null dates should be sorted first when sorting ascending');
        System.assertEquals(null, wrapperList[1].lastModifiedDate, 'Components with null dates should be sorted first when sorting ascending');
        System.assertEquals('prod', wrapperList[2].environment, 'Components should be sorted by last modified date');
        System.assertEquals('int', wrapperList[3].environment, 'The component with the latest date should be sorted last');
    }
}
