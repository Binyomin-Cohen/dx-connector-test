@isTest
private class TestComponentServices {

    static testMethod void countInstances_noData()
    {
        Component__c component = new Component__c();

        Test.startTest();
            ComponentServices.countInstances( new List<Component__c>{ component } );
        Test.stopTest();

        System.assertEquals(0, component.Instance_Count__c, 'Components with no data should have a count of 0.');
    }

    static testMethod void countInstances_invalidData()
    {
        Component__c component = new Component__c();
        component.Field_Modified_Data__c = '{[baddata:';

        Test.startTest();
            ComponentServices.countInstances( new List<Component__c>{ component } );
        Test.stopTest();

        System.assertEquals(1, component.Instance_Count__c, 'Components with invalid data should have a count of 1.');
    }

    static testMethod void countInstances_singleInstance()
    {
        FieldModifiedData instanceData = new FieldModifiedData( 'INT', Datetime.now(), 'bguy', Datetime.now(), 'bguy');

        Component__c component = new Component__c();
        component.Field_Modified_Data__c = Json.serialize( new List<FieldModifiedData>{instanceData} );

        Test.startTest();
            ComponentServices.countInstances( new List<Component__c>{ component } );
        Test.stopTest();

        System.assertEquals(1, component.Instance_Count__c, 'Components with one instance in their field modified data should have a count of 1.');
    }

    static testMethod void countInstances_multiInstance()
    {
        FieldModifiedData instanceData1 = new FieldModifiedData( 'INT', Datetime.now(), 'bguy', Datetime.now(), 'bguy');
        FieldModifiedData instanceData2 = new FieldModifiedData( 'DEV', Datetime.now(), 'bguy', Datetime.now(), 'bguy');
        FieldModifiedData instanceData3 = new FieldModifiedData( 'QA1', Datetime.now(), 'bguy', Datetime.now(), 'bguy');
        List<FieldModifiedData> fieldData = new List<FieldModifiedData>{ instanceData1, instanceData2, instanceData3 };
        Component__c component = new Component__c();
        component.Field_Modified_Data__c = Json.serialize( fieldData );

        Test.startTest();
            ComponentServices.countInstances( new List<Component__c>{ component } );
        Test.stopTest();

        System.assertEquals( fieldData.size(), component.Instance_Count__c, 'Instance count should be set to the number of instances in the field modified data.');
    }

    static testMethod void countInstances_OnInsert()
    {
        FieldModifiedData instanceData1 = new FieldModifiedData( 'INT', Datetime.now(), 'bguy', Datetime.now(), 'bguy');
        FieldModifiedData instanceData2 = new FieldModifiedData( 'DEV', Datetime.now(), 'bguy', Datetime.now(), 'bguy');
        FieldModifiedData instanceData3 = new FieldModifiedData( 'QA1', Datetime.now(), 'bguy', Datetime.now(), 'bguy');
        List<FieldModifiedData> fieldData = new List<FieldModifiedData>{ instanceData1, instanceData2, instanceData3 };
        Component__c component = new Component__c(Name='foo', Full_Name__c='foo', Type__c='Application');
        component.Field_Modified_Data__c = Json.serialize( fieldData );

        Test.startTest();
            insert component;
        Test.stopTest();

        Component__c updatedComponent = [SELECT Instance_Count__c FROM Component__c WHERE Id = :component.Id];
        System.assertEquals( fieldData.size(), updatedComponent.Instance_Count__c, 'Instance count should be set to the number of instances in the field modified data.');
    }

    static testMethod void countInstances_OnUpdate()
    {
        FieldModifiedData instanceData1 = new FieldModifiedData( 'INT', Datetime.now(), 'bguy', Datetime.now(), 'bguy');
        FieldModifiedData instanceData2 = new FieldModifiedData( 'DEV', Datetime.now(), 'bguy', Datetime.now(), 'bguy');
        FieldModifiedData instanceData3 = new FieldModifiedData( 'QA1', Datetime.now(), 'bguy', Datetime.now(), 'bguy');
        List<FieldModifiedData> fieldData = new List<FieldModifiedData>{ instanceData1, instanceData2, instanceData3 };
        Component__c component = new Component__c(Name='test', Full_Name__c = 'test', Type__c='Apex Class');
        insert component;

        Test.startTest();
            component.Field_Modified_Data__c = Json.serialize( fieldData );
            update component;
        Test.stopTest();

        Component__c updatedComponent = [SELECT Instance_Count__c FROM Component__c WHERE Id = :component.Id];
        System.assertEquals( fieldData.size(), updatedComponent.Instance_Count__c, 'Instance count should be set to the number of instances in the field modified data.');
    }

    static testMethod void populateSourceInstances() {
        Instances__c instance1 = new Instances__c(Name='dev');
        insert instance1;

        Test.startTest();
           Component__c component = new Component__c(Name='foo', Full_Name__c='foo', Type__c='Application', Instance__c=instance1.Id);
           insert component;
        Test.stopTest();

        Component__c c = [SELECT Source_Instances__c FROM Component__c WHERE Id = :component.Id];
        System.assertEquals( instance1.Name.toLowerCase(), c.Source_Instances__c.toLowerCase(),
                             'Source instances should be populated from the selected instance');
    }

    static testMethod void createFieldModifiedData_OnInsert() {
        Instances__c instance1 = new Instances__c(Name='dev');
        insert instance1;

        Test.startTest();
           Component__c component = new Component__c(Name='foo', Full_Name__c='foo', Type__c='Application', Instance__c=instance1.Id);
           insert component;
        Test.stopTest();

        Component__c c = [SELECT Instance_Count__c, Instance__c, Field_Modified_Data__c FROM Component__c WHERE Id = :component.Id];
        List<FieldModifiedData> fieldData = (List<FieldModifiedData>) JSON.deserialize(c.Field_Modified_Data__c, List<FieldModifiedData>.class);

        System.assertEquals( 1, fieldData.size(), 'Field Modified Data should have 1 instance');
        System.assertEquals( 'dev', fieldData[0].environmentName, 'Field Modified Data should have 1 instance');
        System.assertEquals( null, fieldData[0].lastModifiedDate, 'Last Modified Date should be null');
        System.assertEquals( null, fieldData[0].lastModifiedByName, 'Last Modified By Name should be null');
        System.assertEquals( null, fieldData[0].createdDate, 'Created Date should be null');
        System.assertEquals( null, fieldData[0].createdByName, 'Created By Name should be null');

        System.assertEquals( null, c.Instance__c, 'Instance__c should be null');
        System.assertEquals( 1, c.Instance_Count__c, 'Instance count should be 1');
    }

    static testMethod void createFieldModifiedData_OnUpdate() {
        Instances__c instance1 = new Instances__c(Name='dev');
        insert instance1;

        Instances__c instance2 = new Instances__c(Name='prod');
        insert instance2;

        Component__c component = new Component__c(Name='foo', Full_Name__c='foo', Type__c='Application', Instance__c=instance1.Id);
        insert component;

        Test.startTest();
           component.Instance__c = instance2.Id;
           update component;
        Test.stopTest();

        Component__c c = [SELECT Instance_Count__c, Instance__c, Field_Modified_Data__c FROM Component__c WHERE Id = :component.Id];
        List<FieldModifiedData> fieldData = (List<FieldModifiedData>) JSON.deserialize(c.Field_Modified_Data__c, List<FieldModifiedData>.class);

        System.assertEquals( 2, fieldData.size(), 'Field Modified Data should have 1 instances');
        System.assertEquals( 'dev', fieldData[0].environmentName, 'Field Modified Data should have 1 instance');

        System.assertEquals( null, fieldData[0].lastModifiedDate, 'Last Modified Date should be null');
        System.assertEquals( null, fieldData[0].lastModifiedByName, 'Last Modified By Name should be null');
        System.assertEquals( null, fieldData[0].createdDate, 'Created Date should be null');
        System.assertEquals( null, fieldData[0].createdByName, 'Created By Name should be null');

        System.assertEquals( 'prod', fieldData[1].environmentName, 'Field Modified Data should have 1 instance');
        System.assertEquals( null, fieldData[1].lastModifiedDate, 'Last Modified Date should be null');
        System.assertEquals( null, fieldData[1].lastModifiedByName, 'Last Modified By Name should be null');
        System.assertEquals( null, fieldData[1].createdDate, 'Created Date should be null');
        System.assertEquals( null, fieldData[1].createdByName, 'Created By Name should be null');

        System.assertEquals( null, c.Instance__c, 'Instance__c should be null');
        System.assertEquals( 2, c.Instance_Count__c, 'Instance count should be 2');
    }

    static testMethod void testUpdateInstanceName(){
        String oldInstanceName = 'prod';
        String newInstanceName = 'new_instance_name';
        Instances__c instanceProd = new Instances__c(Name=oldInstanceName, Type__c='Production / Developer');
        insert instanceProd;

        Component__c componentWithProdEnvData = TestingUtils.buildComponent('Test object', 'Object', instanceProd.Id);
        insert componentWithProdEnvData;

        Test.startTest();
           ComponentServices.renameInstanceName(componentWithProdEnvData, oldInstanceName, newInstanceName);
        Test.stopTest();

        Set<String> srcInstances = new Set<String>(componentWithProdEnvData.Source_Instances__c.split(';'));
        List<FieldModifiedData> fieldData = (List<FieldModifiedData>) JSON.deserialize(componentWithProdEnvData.Field_Modified_Data__c, List<FieldModifiedData>.class);

        System.assert(!srcInstances.contains(oldInstanceName), 'We do not expect the source instances to contain the old instance name.');
        System.assert(srcInstances.contains(newInstanceName), 'We do expect the source instances to contain the old instance name.');
        System.assertEquals(1, fieldData.size(), 'There should only be one Field Modified Data record on the component.');
        System.assertEquals(newInstanceName, fieldData[0].environmentName, 'The old instance name should have been replaced with the new name');
    }

    static testMethod void testUpdateInstanceName_noEnvironmentName(){
        String oldInstanceName = 'prod';
        String newInstanceName = 'new_instance_name';
        Instances__c instanceProd = new Instances__c(Name=oldInstanceName, Type__c='Production / Developer');
        insert instanceProd;

        FieldModifiedData prodEnvData1 = new FieldModifiedData( null,  Datetime.now().addDays(-1), null, null, null);

        Component__c componentWithProdEnvData = TestingUtils.buildComponent('Test object', 'Object', null);
        insert componentWithProdEnvData;
        componentWithProdEnvData.Field_Modified_Data__c = JSON.serialize(new List<FieldModifiedData>{prodEnvData1});

        Test.startTest();
           ComponentServices.renameInstanceName(componentWithProdEnvData, oldInstanceName, newInstanceName);
        Test.stopTest();

        Set<String> srcInstances = new Set<String>(componentWithProdEnvData.Source_Instances__c.split(';'));
        List<FieldModifiedData> fieldData = (List<FieldModifiedData>) JSON.deserialize(componentWithProdEnvData.Field_Modified_Data__c, List<FieldModifiedData>.class);

        System.assert(!srcInstances.contains(oldInstanceName), 'We do not expect the source instances to contain the old instance name.');
        System.assert(srcInstances.contains(newInstanceName), 'We do expect the source instances to contain the old instance name.');
        System.assertEquals(1, fieldData.size(), 'There should only be one Field Modified Data record on the component.');
        System.assertEquals(newInstanceName, fieldData[0].environmentName, 'The old instance name should have been replaced with the new name');
    }

    static testMethod void testSetKey_WithParent() {
        Component__c pc = new Component__c(Name='Foo', Full_Name__c='Foo', Type__c= 'Object');
        insert pc;

        String name = 'a'.repeat(10);
        String type = 'b'.repeat(8);

        Component__c c = TestingUtils.buildComponentWithParent(name, type, pc.Id);

        Test.startTest();
           ComponentServices.setKey(c);
        Test.stopTest();

        System.assert(!String.isBlank(c.Key__c), 'The Key__c field should have been set');
    }

    static testMethod void testSetKey_WithNoParent() {
        String name = 'a'.repeat(10);
        String type = 'b'.repeat(8);

        Component__c c = TestingUtils.buildComponentWithParent(name, type, '');

        Test.startTest();
           ComponentServices.setKey(c);
        Test.stopTest();

        System.assert(!String.isBlank(c.Key__c), 'The Key__c field should have been set');
    }

    static testMethod void testSetKey_GreaterThanMaxLength() {
        String name = 'a'.repeat(255);
        String type = 'b'.repeat(8);

        Component__c c = TestingUtils.buildComponentWithParent(name, type, '');

        Test.startTest();
           ComponentServices.setKey(c);
        Test.stopTest();

        System.assert(!String.isBlank(c.Key__c), 'The Key__c field should have been set');
    }

    static testMethod void testSetKey_MixedCase() {
        Component__c c1 = TestingUtils.buildComponentWithParent('Foo', 'Apex Class', '');
        Component__c c2 = TestingUtils.buildComponentWithParent('foo', 'Apex Class', '');

        Test.startTest();
           ComponentServices.setKey(c1);
           ComponentServices.setKey(c2);
        Test.stopTest();

        System.assertNotEquals(c1.Key__c, c2.Key__c, 'The Key__c field should be case sensitive');
    }

    static testMethod void getComponentLastModifiedByUsernamesInsertsUniqueUsersFromFieldModifiedData() {
        String USERNAME = 'Target User';
        String USERNAME2 = 'Target User2';

        Instances__c instance = TestingUtils.createInstance('dev');
        Component__c component = TestingUtils.createComponent('Test trigger', 'Trigger', instance.Id);

        FieldModifiedData lastModifiedData0 = new FieldModifiedData(instance.Name, null, USERNAME, null, 'somebody');
        FieldModifiedData lastModifiedData1 = new FieldModifiedData(instance.Name, null, USERNAME, null, 'somebody');
        FieldModifiedData lastModifiedData2 = new FieldModifiedData(instance.Name, null, USERNAME2, null, 'somebody');
        FieldModifiedData lastModifiedDataNoUser = new FieldModifiedData('Environment Name');
        component.Field_Modified_Data__c = JSON.serialize(new List<FieldModifiedData>{lastModifiedData0, lastModifiedData1, lastModifiedData2, lastModifiedDataNoUser});

        Set<String> lastModifiedByUsernames = ComponentServices.getLastModifiedByUsernames(component);

        System.assertEquals(2, lastModifiedByUsernames.size(), 'lastModifiedByUsernames should contain two elements');
        System.assert(lastModifiedByUsernames.contains(USERNAME), 'lastModifiedByUsernames should contain Target User');
        System.assert(lastModifiedByUsernames.contains(USERNAME2), 'lastModifiedByUsernames should contain Target User2');
    }

    static testMethod void populateLastModifiedUsers() {
        String USERNAME = 'Target User';
        String USERNAME2 = 'Target User2';

        Instances__c instance = TestingUtils.createInstance('dev');
        Component__c component = TestingUtils.buildComponent('Test trigger', 'Trigger', instance.Id);
        Component__c componentNoUser = TestingUtils.buildComponent('Test trigger2', 'Trigger', instance.Id);

        FieldModifiedData lastModifiedData0 = new FieldModifiedData(instance.Name, null, USERNAME, null, 'somebody');
        FieldModifiedData lastModifiedData1 = new FieldModifiedData(instance.Name, null, USERNAME2, null, 'somebody');
        FieldModifiedData lastModifiedDataNoUser = new FieldModifiedData('Environment Name');

        component.Field_Modified_Data__c = JSON.serialize(new List<FieldModifiedData>{
            lastModifiedData0, lastModifiedData1});
        componentNoUser.Field_Modified_Data__c = JSON.serialize(new List<FieldModifiedData>{lastModifiedDataNoUser});

        Test.startTest();
        Set<String> allModifiedUsers =
                ComponentServices.populateLastModifiedUsers(new List<Component__c>{component, componentNoUser});
        Test.stopTest();

        Set<String> lastModifiedUsers = new Set<String>(component.Last_Modified_Users__c.split(';'));
        System.assertEquals(2, lastModifiedUsers.size(),
                'Last_Modified_Users__c should be populated with all users from the field modified data');
        System.assert(lastModifiedUsers.contains(USERNAME),
                'Last_Modified_Users__c should be populated with all users from the field modified data');
        System.assert(lastModifiedUsers.contains(USERNAME2),
                'Last_Modified_Users__c should be populated with all users from the field modified data');

        System.assert(String.isBlank(componentNoUser.Last_Modified_Users__c),
                'When there are no users, the Last_Modified_Users__c  should be blank');

        System.assertEquals(2, allModifiedUsers.size(), 'All users should be aggregated');
        System.assert(allModifiedUsers.contains(USERNAME), 'All users should be aggregated');
        System.assert(allModifiedUsers.contains(USERNAME2), 'All users should be aggregated');
    }

    static testMethod void getReferencesStringJSON_allFieldsSet() {
        List<String> values = new List<String>();
        values.add('reference-id1');
        values.add('reference-id2');
        values.add('reference-id3');
        values.add('reference-id4');
        values.add('reference-id5');

        Component__c c = new Component__c();
        c.Reference_Data_1__c = values[0];
        c.Reference_Data_2__c = values[1];
        c.Reference_Data_3__c = values[2];
        c.Reference_Data_4__c = values[3];
        c.Reference_Data_5__c = values[4];

        String expected = String.join(values, '');

        Test.startTest();
            String actual = ComponentSearchWrapper.getReferencesStringJSON(c);
        Test.stopTest();

        System.assertEquals(expected, actual, 'Values from all fields should be joined');
    }

    static testMethod void getReferencesStringJSON_firstFieldSet() {
        List<String> values = new List<String>();
        values.add('reference-id1');

        Component__c c = new Component__c();
        c.Reference_Data_1__c = values[0];

        String expected = String.join(values, '');

        Test.startTest();
            String actual = ComponentSearchWrapper.getReferencesStringJSON(c);
        Test.stopTest();

        System.assertEquals(expected, actual, 'Values from all fields should be joined');
    }

    static testMethod void getReferencesStringJSON_deserialize() {
        String partial1 = '[{\"Instance\":\"Instance A\",\"References\":\"aa';
        String partial2 = 'aaa\"},{\"Instance\":\"Instance B\",\"References\":\"bbbbb\"}]';
        List<String> values = new List<String>();
        values.add(partial1);
        values.add(partial2);

        Component__c c = new Component__c();
        c.Reference_Data_1__c = values[0];
        c.Reference_Data_2__c = values[1];

        Test.startTest();
            String referencesJSON = ComponentSearchWrapper.getReferencesStringJSON(c);
            List<ComponentSearchWrapper.ComponentReference> deserializedList =
                (List<ComponentSearchWrapper.ComponentReference>) JSON.deserialize(referencesJSON,
                    List<ComponentSearchWrapper.ComponentReference>.class);
        Test.stopTest();

        String expectedAName = 'Instance A';
        String expectedAReferences = 'aaaaa';
        String expectedBName = 'Instance B';
        String expectedBReferences = 'bbbbb';

        System.assertEquals(2, deserializedList.size(), 'Values from all fields should be joined');
        for (ComponentSearchWrapper.ComponentReference cr : deserializedList) {
            if (cr.instance.equals(expectedAName)) {
                System.assertEquals(expectedAReferences, cr.references,
                  'The references string should be read in from the correct instance name');
            } else if (cr.instance.equals(expectedBName)) {
                System.assertEquals(expectedBReferences, cr.references,
                  'The references string should be read in from the correct instance name');
            } else {
                System.assert(false, 'Unexpected instance name found');
            }
        }
    }

    static testMethod void createComponentKey_emptyKeys() {
        String componentName = null;
        String type = null;
        String parentName = null;

        Test.startTest();
            String allNullKey = ComponentServices.createComponentKey(componentName, type, parentName);
            String nullComponentNameKey = ComponentServices.createComponentKey(componentName, 'bad', 'parenting');
            String nullTypeNameKey = ComponentServices.createComponentKey('child', type, 'parenting');
            String nullCompAndTypeKey = ComponentServices.createComponentKey(componentName, type, 'parenting');
        Test.stopTest();

        System.assertEquals('', allNullKey,
                'The key should be an empty string because all null values have been passed in.');
        System.assertEquals('', nullComponentNameKey,
                'The key should be an empty string because the component name is null.');
        System.assertEquals('', nullTypeNameKey,
                'The key should be an empty string because the type is null.');
        System.assertEquals('', nullCompAndTypeKey,
                'The key should be an empty string because the component name and type are null.');
    }

    static testMethod void createComponentKey_validKeys() {
        String componentName = 'child';
        String type = 'type';
        String parentName = 'parent';

        Test.startTest();
            String allPopulatedKey = ComponentServices.createComponentKey(componentName, type, parentName);
            String emptyParentKey = ComponentServices.createComponentKey(componentName, type, '');
            String nullParentKey = ComponentServices.createComponentKey(componentName, type, null);
        Test.stopTest();

        String expectedFullKey = componentName + '|' + type + '|' + parentName;
        String expectedEmptyParentKey = componentName + '|' + type + '|';

        System.assertEquals(expectedFullKey, allPopulatedKey,
                'The key should have the component name, type and parent name populated.');
        System.assertEquals(expectedEmptyParentKey, emptyParentKey,
                'The key should have the component name and type populated.');
        System.assertEquals(expectedEmptyParentKey, nullParentKey,
                'The key should have the component name and type populated.');
    }

    static testMethod void removeDeletedInstances_noDeletedInstancesFound() {
        final String ACTIVE_INSTANCE_NAME = 'testActive1';
        final String ACTIVE_INSTANCE_NAME_2 = 'testActive2';
        final String DELETED_INSTANCE_NAME = 'test2';

        String expectedInstances = ACTIVE_INSTANCE_NAME + ';' + ACTIVE_INSTANCE_NAME_2;

        Component__c testComponent = new Component__c (Source_Instances__c = expectedInstances);
        Set<String> deletedInstances = new Set<String>{DELETED_INSTANCE_NAME};

        Test.startTest();
            String actualInstanceNames = ComponentServices.removeDeletedInstancesFromSourceInstancesField(testComponent, deletedInstances);
        Test.stopTest();

        System.assertEquals(expectedInstances, actualInstanceNames, 'No instance names should be removed');
    }

    static testMethod void removeDeletedInstances_oneDeletedInstanceFound() {
        final String ACTIVE_INSTANCE_NAME = 'testActive1';
        final String ACTIVE_INSTANCE_NAME_2 = 'testActive2';
        final String DELETED_INSTANCE_NAME = 'test2';

        String expectedInstances = ACTIVE_INSTANCE_NAME + ';' + ACTIVE_INSTANCE_NAME_2;

        Component__c testComponent = new Component__c (Source_Instances__c = expectedInstances + ';' + DELETED_INSTANCE_NAME);
        Set<String> deletedInstances = new Set<String>{DELETED_INSTANCE_NAME};

        Test.startTest();
            String actualInstanceNames = ComponentServices.removeDeletedInstancesFromSourceInstancesField(testComponent, deletedInstances);
        Test.stopTest();

        System.assertEquals(expectedInstances, actualInstanceNames, 'One instance name should be removed');
    }
}