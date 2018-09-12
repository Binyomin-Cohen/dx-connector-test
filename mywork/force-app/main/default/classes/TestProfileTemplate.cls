@isTest
private class TestProfileTemplate {

    static testMethod void getApiName_default() {

        String name = 'Henry';

        Test.startTest();
            String apiName = ProfileTemplate.getApiName(name, 'trigger', null);
        Test.stopTest();

        System.assertEquals(name, apiName, 'By default, the api name should be set to the component name');
    }

    static testMethod void getApiName_layouts() {

        String parent = 'Backlog';
        String name = 'defect';

        Test.startTest();
            String apiName = ProfileTemplate.getApiName(name, ComponentServices.LAYOUT_ALM_NAME, parent);
        Test.stopTest();

        System.assertEquals(parent + '-' + name, apiName, 'Layouts should include the parent name in the api name');
    }

    static testMethod void templatePermission_layoutLabel() {
        Instances__c instance = TestingUtils.createInstance('dev');
        Component__c parent = TestingUtils.createComponent('Backlog__c', ComponentServices.OBJECT_ALM_NAME, instance.Id );
        Component__c layoutComponent = TestingUtils.buildComponentWithParent('', ComponentServices.LAYOUT_ALM_NAME, parent.Id);

        insert layoutComponent;

        layoutComponent.Parent_Component__r = parent;

        Test.startTest();

            ProfileTemplate.Permission permission = new ProfileTemplate.Permission(layoutComponent);

        Test.stopTest();

        String expectedLabel = '[' + parent.Name +'] ' + layoutComponent.Name;
        System.assertEquals(expectedLabel, permission.label, 'The permission label should contain the layout parent object name' );

    }

    static testMethod void section_addPermissions_customMetadataTypes() {
        Instances__c instance = TestingUtils.createInstance('dev');

        Component__c customMetadataComponent =
            TestingUtils.createComponent('Profile_Permissions__mdt', ComponentServices.OBJECT_ALM_NAME, instance.Id );

        ProfileTemplate.Permission customMetadataPermission
            = new ProfileTemplate.Permission(customMetadataComponent);

        List<Profile_Permission_Data__mdt> categories = [
            SELECT Id, Help_Text__c, DeveloperName, Is_Category__c, Category__c, Order__c, Option_Label__c, Option_Value__c, Has_Sub_Sections__c
            FROM Profile_Permission_Data__mdt
            WHERE Is_Category__c = true
             AND Has_Sub_Sections__c = true
            LIMIT 1
        ];

        ProfileTemplate.Section section = new ProfileTemplate.Section(categories[0]);

        Test.startTest();
            section.addPermissions( new List<ProfileTemplate.Permission>{customMetadataPermission});
        Test.stopTest();

        System.assertEquals(1, section.customPermissions.size(),
             'custom metadata types should be addded to the custom permissions list');
        System.assertEquals(0, section.standardPermissions.size(),
             'custom metadata types should be addded to the custom permissions list');
    }

}