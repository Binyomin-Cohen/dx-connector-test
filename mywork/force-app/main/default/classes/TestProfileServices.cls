@isTest
private class TestProfileServices {

    static Instances__c instance;
    static Instances__c instance2;

    static void setup() {
        instance = new Instances__c(Name='dev', Type__c='Production / Developer');
        instance2 = new Instances__c(Name='prod', Type__c='Production / Developer');
        insert new List<Instances__c>{instance, instance2};
    }

    static testMethod void getPermissionsMap_layouts() {
        
        setup();
        
        Release__c release = new Release__c(Name='Summer 14');
        insert release;

        Backlog__c backlogItem = new Backlog__c(Release__c=release.Id, Status__c='Complete');
        insert backlogItem;

        Component__c parent = TestingUtils.createComponent('Backlog__c', ComponentServices.OBJECT_ALM_NAME, instance.Id );
        Component__c layoutComponent = TestingUtils.buildComponentWithParent('defect', ComponentServices.LAYOUT_ALM_NAME, parent.Id);
        insert layoutComponent;

        Backlog_Component__c backlogComponent = new Backlog_Component__c(Backlog__c = backlogItem.Id,
             Component__c = layoutComponent.Id, Source_Instance__c = instance.Id, Notes__c = 'a note');
        insert backlogComponent;
        
        List<AssemblerManifestRecord> records = AssemblerServices.getManifest(release.Id); 
        
        Test.startTest();
            Map<String, Set<String>> documentedPermissionsMap = ProfileServices.getPermissionsMap(records);
        Test.stopTest();
        
        System.assertEquals(1, documentedPermissionsMap.size(), 'There should be one entry for the layout category in the documented map');
        
        Set<String> layoutPermissions = documentedPermissionsMap.get(ProfileServices.LAYOUT_API_NAME);
        
        System.assertEquals(1, layoutPermissions.size(), 'There should be one entry for the layout component in the documented map');
        
        String expectedKey = parent.Name + '-' + layoutComponent.Name + ProfileServices.PROFILE_NAME_INSTANCE_DELIMETER + instance.Name;
        
        System.assert( layoutPermissions.contains(expectedKey), 'The layout component should be in the documented map');
    }
    
    static testMethod void generateProfileTemplate() {
        setup();
        Component__c component1 = TestingUtils.createComponent('class 1', 'Apex Class', instance.Id);
        Component__c component2 = TestingUtils.createComponent('class 2', 'Apex Class', instance.Id);

        Test.startTest();
            ProfileTemplate profileTemplate = ProfileServices.generateProfileTemplate(instance.Name);
        Test.stopTest();

        System.assertEquals(instance.Name, profileTemplate.instanceName, 'The instance name should be set on the profile template');

        List<Profile_Permission_Data__mdt> categories = ProfileServices.getProfilePermissionData(true);

        System.assertEquals(categories.size(), profileTemplate.sections.size(), 'The number of sections in the template should equal the number of profile categories');

        Map<String, ProfileTemplate.Section> nameToCategory = mapSectionsByLabel(profileTemplate);

        System.assertEquals(true, nameToCategory.containsKey('Apex Class Access'), 'There should be a category for apex classes');

        ProfileTemplate.Section apexSection = nameToCategory.get('Apex Class Access');

        System.assertEquals(2, apexSection.permissions.size(), 'There should be a permission for each apex component');
        System.assertEquals(component1.Name, apexSection.permissions[0].apiName, 'Permissions should be ordered by Name');
        System.assertEquals(component2.Name, apexSection.permissions[1].apiName, 'Permissions should be ordered by Name');
    }

    static testMethod void generateProfileTemplate_tabVisibilities_returnsAllTabTypes() {
        setup();
        Component__c component1 = TestingUtils.createComponent('custom_object_tab__c', 'Custom Object Tab', instance.Id);
        Component__c component2 = TestingUtils.createComponent('web tab', 'Web Tab', instance.Id);
        Component__c component3 = TestingUtils.createComponent('vf tab', 'Visualforce Tab', instance.Id);

//        Component__c component4 = TestingUtils.createComponent('Account', 'Custom Object Tab', instance.Id);
//        Component__c component5 = TestingUtils.createComponent('Lead', 'Custom Object Tab', instance.Id);

        Test.startTest();
            ProfileTemplate profileTemplate = ProfileServices.generateProfileTemplate(instance.Name);
        Test.stopTest();

        List<Profile_Permission_Data__mdt> categories = ProfileServices.getProfilePermissionData(true);

        System.assertEquals(categories.size(), profileTemplate.sections.size(), 'The number of sections in the template should equal the number of profile categories');

        Map<String, ProfileTemplate.Section> nameToCategory = mapSectionsByLabel(profileTemplate);

        System.assertEquals(true, nameToCategory.containsKey('Tab Settings'), 'There should be a category for tab settings');

        ProfileTemplate.Section tabSection = nameToCategory.get('Tab Settings');

        System.assertEquals(3, tabSection.customPermissions.size(), 'There should be a permission for each tab component');
        System.assertEquals(component1.Name, tabSection.customPermissions[0].apiName, 'Permissions should be ordered by Name');
        System.assertEquals(component3.Name, tabSection.customPermissions[1].apiName, 'Permissions should be ordered by Name');
        System.assertEquals(component2.Name, tabSection.customPermissions[2].apiName, 'Permissions should be ordered by Name');

        //TODO: need to handle standard tabs
        //System.assertEquals(component4.Name, tabSection.standardPermissions[0].apiName, 'Permissions should be ordered by Name');
        //System.assertEquals(component5.Name, tabSection.standardPermissions[1].apiName, 'Permissions should be ordered by Name');
    }

    //TODO: test custom metadata profile template construction

    static testMethod void refreshProfileTemplateCacheInFuture() {
        setup();
        Component__c component1 = TestingUtils.createComponent('class 1', 'Apex Class', instance.Id);
        Component__c component2 = TestingUtils.createComponent('class 2', 'Apex Class', instance.Id);

        Test.startTest();
            ProfileServices.refreshProfileTemplateCacheInFuture(instance.Id);
        Test.stopTest();

        ProfileTemplate.ProfileTemplateState cachedState = new ProfileTemplate.ProfileTemplateState(instance.Name);
        ProfileServices.getCache().getData( cachedState );

        ProfileTemplate profileTemplate = cachedState.getTemplate();

        List<Profile_Permission_Data__mdt> categories = ProfileServices.getProfilePermissionData(true);
        System.assertEquals(categories.size(), profileTemplate.sections.size(), 'The number of sections in the template should equal the number of profile categories');

        Map<String, ProfileTemplate.Section> nameToCategory = mapSectionsByLabel(profileTemplate);

        System.assertEquals(true, nameToCategory.containsKey('Apex Class Access'), 'There should be a category for apex classes');

        ProfileTemplate.Section apexSection = nameToCategory.get('Apex Class Access');

        System.assertEquals(2, apexSection.permissions.size(), 'There should be a permission for each apex component in this instance');
    }

    static testMethod void retrieveProfileTemplate() {
        setup();

        Test.startTest();
            ProfileTemplate profileTemplate = ProfileServices.retrieveProfileTemplate(instance.Name);
        Test.stopTest();

        System.assertEquals(instance.Name, profileTemplate.instanceName, 'The profile template should be returned even if it has not been cached yet');

        List<Profile_Permission_Data__mdt> categories = ProfileServices.getProfilePermissionData(true);
        System.assertEquals(categories.size(), profileTemplate.sections.size(), 'The number of sections in the template should equal the number of profile categories');
    }

    static testMethod void retrieveProfileTemplates_multipleInstances() {
        setup();

        String sectionName = 'test_section';
        String sectionLabel = 'test section';

        Component__c testComponent = TestingUtils.createComponent('class 1', 'Apex Class', instance.Id);
        Component__c testComponent2 = TestingUtils.createComponent('class 2', 'Apex Class', instance2.Id);

        List<String> instanceNames = new List<String>{instance.Name, instance2.Name};

        Profile_Permission_Data__mdt testPermissionData = ProfileServices.getProfilePermissionData(true)[0];

        List<ProfileTemplate.Section> sections = new List<ProfileTemplate.Section>();
        List<ProfileTemplate.Section> sections2 = new List<ProfileTemplate.Section>();

        ProfileTemplate.Permission testComponentPermission = new ProfileTemplate.Permission(testComponent);
        ProfileTemplate.Permission testComponent2Permission = new ProfileTemplate.Permission(testComponent2);

        ProfileTemplate.Section section = new ProfileTemplate.Section(testPermissionData);
        section.permissions.addAll( new List<ProfileTemplate.Permission>{ testComponentPermission } );
        section.standardPermissions.addAll( new List<ProfileTemplate.Permission>{testComponentPermission} );
        section.customPermissions.addAll( new List<ProfileTemplate.Permission>{testComponentPermission} );

        ProfileTemplate.Section section2 = new ProfileTemplate.Section(testPermissionData);
        section2.permissions.addAll( new List<ProfileTemplate.Permission>{testComponent2Permission} );
        section2.standardPermissions.addAll( new List<ProfileTemplate.Permission>{testComponentPermission, testComponent2Permission} );
        section2.customPermissions.addAll( new List<ProfileTemplate.Permission>{testComponentPermission} );

        sections.add(section);
        sections2.add(section2);

        ProfileTemplate template = new ProfileTemplate(instance.Name, sections);
        ProfileTemplate template2 = new ProfileTemplate(instance2.Name, sections2);

        ProfileTemplate.ProfileTemplateState cachedState = new ProfileTemplate.ProfileTemplateState(template);
        ProfileTemplate.ProfileTemplateState cachedState2 = new ProfileTemplate.ProfileTemplateState(template2);
        ProfileServices.getCache().putData(cachedState);
        ProfileServices.getCache().putData(cachedState2);

        Test.startTest();
            ProfileTemplate profileTemplate = ProfileServices.retrieveProfileTemplate(instanceNames);
        Test.stopTest();

        System.assertEquals(1, profileTemplate.sections.size(), 'The profile template should have one merged section from both templates');
        System.assertEquals(2, profileTemplate.sections[0].permissions.size(), 'The permissions section should have been merged from both profile templates');
        System.assertEquals(2, profileTemplate.sections[0].standardPermissions.size(), 'The standard permissions section should have been merged from both profile templates');
        System.assertEquals(1, profileTemplate.sections[0].customPermissions.size(), 'The custom permissions section should have been merged from both profile templates');
    }

    static testMethod void retrieveProfileTemplates_multipleInstances_differentSections() {
        setup();

        String sectionName = 'test_section';
        String sectionLabel = 'test section';

        Component__c testComponent = TestingUtils.createComponent('class 1', 'Apex Class', instance.Id);
        Component__c testComponent2 = TestingUtils.createComponent('class 2', 'Apex Class', instance2.Id);

        List<String> instanceNames = new List<String>{instance.Name, instance2.Name};

        List<Profile_Permission_Data__mdt> allPermissionData = ProfileServices.getProfilePermissionData(true);
        Profile_Permission_Data__mdt testPermissionData1 = allPermissionData[0];
        Profile_Permission_Data__mdt testPermissionData2 = allPermissionData[1];

        List<ProfileTemplate.Section> sections = new List<ProfileTemplate.Section>();
        List<ProfileTemplate.Section> sections2 = new List<ProfileTemplate.Section>();

        ProfileTemplate.Permission testComponentPermission = new ProfileTemplate.Permission(testComponent);
        ProfileTemplate.Permission testComponent2Permission = new ProfileTemplate.Permission(testComponent2);

        ProfileTemplate.Section section = new ProfileTemplate.Section(testPermissionData1);
        section.permissions.addAll( new List<ProfileTemplate.Permission>{ testComponentPermission } );
        section.standardPermissions.addAll( new List<ProfileTemplate.Permission>{testComponentPermission} );
        section.customPermissions.addAll( new List<ProfileTemplate.Permission>{testComponentPermission} );

        ProfileTemplate.Section section2 = new ProfileTemplate.Section(testPermissionData2);
        section2.permissions.addAll( new List<ProfileTemplate.Permission>{testComponentPermission, testComponent2Permission} );
        section2.standardPermissions.addAll( new List<ProfileTemplate.Permission>{testComponentPermission, testComponent2Permission} );
        section2.customPermissions.addAll( new List<ProfileTemplate.Permission>{testComponentPermission, testComponentPermission} );

        sections.add(section);
        sections2.add(section2);

        ProfileTemplate template = new ProfileTemplate(instance.Name, sections);
        ProfileTemplate template2 = new ProfileTemplate(instance2.Name, sections2);

        ProfileTemplate.ProfileTemplateState cachedState = new ProfileTemplate.ProfileTemplateState(template);
        ProfileTemplate.ProfileTemplateState cachedState2 = new ProfileTemplate.ProfileTemplateState(template2);
        ProfileServices.getCache().putData(cachedState);
        ProfileServices.getCache().putData(cachedState2);

        Test.startTest();
            ProfileTemplate profileTemplate = ProfileServices.retrieveProfileTemplate(instanceNames);
        Test.stopTest();

        System.assertEquals(2, profileTemplate.sections.size(), 'The profile template should have one merged section from both templates');
        System.assertEquals(testPermissionData1.Order__c, profileTemplate.sections[0].order, 'The template section should be ordered');
        System.assertEquals(1, profileTemplate.sections[0].permissions.size(), 'The permissions section should have been merged from both profile templates');
        System.assertEquals(1, profileTemplate.sections[0].standardPermissions.size(), 'The standard permissions section should have been merged from both profile templates');
        System.assertEquals(1, profileTemplate.sections[0].customPermissions.size(), 'The custom permissions section should have been merged from both profile templates');

        System.assertEquals(testPermissionData2.Order__c, profileTemplate.sections[1].order, 'The template section should be ordered');
        System.assertEquals(2, profileTemplate.sections[1].permissions.size(), 'The permissions section should have been merged from both profile templates');
        System.assertEquals(2, profileTemplate.sections[1].standardPermissions.size(), 'The standard permissions section should have been merged from both profile templates');
        System.assertEquals(2, profileTemplate.sections[1].customPermissions.size(), 'The custom permissions section should have been merged from both profile templates');
    }

    static testMethod void retrieveProfileTemplates_multipleInstances_singleInstance() {
        setup();

        String sectionName = 'test_section';

        Component__c testComponent = TestingUtils.createComponent('class 1', 'Apex Class', instance.Id);

        List<String> instanceNames = new List<String>{instance.Name};

        Profile_Permission_Data__mdt testPermissionData = ProfileServices.getProfilePermissionData(true)[0];

        List<ProfileTemplate.Section> sections = new List<ProfileTemplate.Section>();

        ProfileTemplate.Permission testComponentPermission = new ProfileTemplate.Permission(testComponent);

        ProfileTemplate.Section section = new ProfileTemplate.Section(testPermissionData);
        section.permissions.addAll( new List<ProfileTemplate.Permission>{ testComponentPermission } );
        section.standardPermissions.addAll( new List<ProfileTemplate.Permission>{testComponentPermission} );
        section.customPermissions.addAll( new List<ProfileTemplate.Permission>{testComponentPermission} );

        sections.add(section);

        ProfileTemplate template = new ProfileTemplate(instance.Name, sections);

        ProfileTemplate.ProfileTemplateState cachedState = new ProfileTemplate.ProfileTemplateState(template);
        ProfileServices.getCache().putData(cachedState);

        Test.startTest();
            ProfileTemplate profileTemplate = ProfileServices.retrieveProfileTemplate(instanceNames);
        Test.stopTest();

        System.assertEquals(1, profileTemplate.sections.size(), 'The profile template should remain unchanged when there is a single template');
        System.assertEquals(1, profileTemplate.sections[0].permissions.size(), 'The permissions section should remain unchanged when there is a single template');
        System.assertEquals(1, profileTemplate.sections[0].standardPermissions.size(), 'The standard permissions section should remain unchanged when there is a single template');
        System.assertEquals(1, profileTemplate.sections[0].customPermissions.size(), 'The custom permissions section should remain unchanged when there is a single template');
    }

    static testMethod void filterComponents_invalidType() {
        String testComponentName = 'Test Component Name';

        setup();
        Backlog__c backlog = new Backlog__c(Status__c = 'Test Status');
        insert backlog;
        Component__c component = new Component__c(
            Name = testComponentName, Full_Name__c = testComponentName, Type__c = 'Invalid Type'
        );
        insert component;
        Backlog_Component__c backlogComponent = new Backlog_Component__c(
            Backlog__c = backlog.Id, Backlog__r = backlog, Component__c = component.Id, Component__r = component, 
            Source_Instance__c = instance.Id, Notes__c = 'Test Note'
        );
        insert backlogComponent;

        List<AssemblerManifestRecord> components = new List<AssemblerManifestRecord>();
        components.add(new AssemblerManifestRecord(backlogComponent));

        Test.startTest();

            Map<String, Set<String>> result = ProfileServices.filterComponents(components);

        Test.stopTest();

        System.assertNotEquals(null, result, 'The result should not be null.');
        System.assertEquals(0, result.size(), 'There should be no results.');
    }

    static testMethod void filterComponents_notField() {
        String testComponentName = 'Test Component Name';

        setup();
        Backlog__c backlog = new Backlog__c(Status__c = 'Test Status');
        insert backlog;
        Component__c component = new Component__c(
            Name = testComponentName, Full_Name__c = testComponentName, Type__c = ComponentServices.APEX_ALM_NAME
        );
        insert component;
        Backlog_Component__c backlogComponent = new Backlog_Component__c(
            Backlog__c = backlog.Id, Backlog__r = backlog, Component__c = component.Id, Component__r = component, 
            Source_Instance__c = instance.Id, Notes__c = 'Test Note'
        );
        insert backlogComponent;

        List<AssemblerManifestRecord> components = new List<AssemblerManifestRecord>();
        components.add(new AssemblerManifestRecord(backlogComponent));

        Test.startTest();

            Map<String, Set<String>> result = ProfileServices.filterComponents(components);

        Test.stopTest();

        System.assertNotEquals(null, result, 'The result should not be null.');
        System.assertEquals(1, result.size(), 'There should be one result.');
        System.assert(result.keySet().contains(ProfileServices.COMPONENT_TYPE_TO_CATEGORY.get(ComponentServices.APEX_ALM_NAME)), 'The component type should be returned.');
        System.assert(result.get(ProfileServices.COMPONENT_TYPE_TO_CATEGORY.get(ComponentServices.APEX_ALM_NAME)).contains(testComponentName), 'The component name should be returned.');
    }

    static testMethod void filterComponents_field() {
        String testParentComponentName = 'Test Parent Component Name';
        String testComponentName = 'Test Component Name';

        setup();
        Backlog__c backlog = new Backlog__c(Status__c = 'Test Status');
        insert backlog;
        Component__c parentComponent = new Component__c(
            Name = testParentComponentName, Full_Name__c = testParentComponentName, Type__c = ComponentServices.OBJECT_ALM_NAME
        );
        insert parentComponent;
        Component__c component = new Component__c(
            Parent_Component__r = parentComponent,
            Name = testComponentName, Full_Name__c = testComponentName, Type__c = ComponentServices.FIELD_ALM_NAME
        );
        insert component;
        Backlog_Component__c backlogComponent = new Backlog_Component__c(
            Backlog__c = backlog.Id, Backlog__r = backlog, Component__c = component.Id, Component__r = component, 
            Source_Instance__c = instance.Id, Notes__c = 'Test Note'
        );
        insert backlogComponent;

        List<AssemblerManifestRecord> components = new List<AssemblerManifestRecord>();
        components.add(new AssemblerManifestRecord(backlogComponent));

        Test.startTest();

            Map<String, Set<String>> result = ProfileServices.filterComponents(components);

        Test.stopTest();

        System.assertNotEquals(null, result, 'The result should not be null.');
        System.assertEquals(1, result.size(), 'There should be one result.');
        System.assert(result.keySet().contains(ProfileServices.COMPONENT_TYPE_TO_CATEGORY.get(ComponentServices.FIELD_ALM_NAME)), 'The component type should be returned.');
        System.assert(result.get(ProfileServices.COMPONENT_TYPE_TO_CATEGORY.get(ComponentServices.FIELD_ALM_NAME)).contains(testParentComponentName), 'The parent component name should be returned.');
    }

    private static Map<String, ProfileTemplate.Section> mapSectionsByLabel(ProfileTemplate profileTemplate) {
        Map<String, ProfileTemplate.Section> nameToCategory = new Map<String, ProfileTemplate.Section>();
        for (ProfileTemplate.Section category : profileTemplate.sections) {
            nameToCategory.put(category.label, category);
        }

        return nameToCategory;
    }
}