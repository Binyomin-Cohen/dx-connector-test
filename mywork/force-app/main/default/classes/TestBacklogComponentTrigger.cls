@isTest
private class TestBacklogComponentTrigger {
    static testMethod void removeDeletedBacklogComponentsFromProfileData_noDelete_unrelated() {
        String testProfileComponentName = 'Test Profile Component Name';
        String testOtherComponentName = 'Test Other Component Name';
        String testComponentType = ComponentServices.APEX_ALM_NAME;
        String profileJSON = generateProfileJSON(
            testProfileComponentName, 
            new Set<String>{ 'Test Instance' }, 
            new Map<String, Set<String>>{ 
                ProfileServices.COMPONENT_TYPE_TO_CATEGORY.get(testComponentType) => new Set<String>{ testOtherComponentName }
            }
        );

        Backlog__c backlogItem = new Backlog__c();
        insert backlogItem;
        Component__c profileComponent = new Component__c(Name = testProfileComponentName, Type__c = 'Profile');
        Component__c otherComponent = new Component__c(Name = 'Test Unrelated Component Name', Type__c = testComponentType);
        insert new List<Component__c>{ profileComponent, otherComponent };
        Backlog_Component__c profileBacklogComponent = new Backlog_Component__c(
            Backlog__c = backlogItem.Id, Component__c = profileComponent.Id, Component__r = profileComponent, 
            Profile_Data_1__c = profileJSON
        );
        Backlog_Component__c deletedBacklogComponent = new Backlog_Component__c(
            Backlog__c = backlogItem.Id, Component__c = otherComponent.Id, Component__r = otherComponent
        );
        insert new List<Backlog_Component__c>{ profileBacklogComponent, deletedBacklogComponent };

        Test.startTest();

            delete deletedBacklogComponent;

        Test.stopTest();

        List<Backlog_Component__c> backlogComponents = [
            SELECT Component__r.Name, Profile_Data_1__c, Profile_Data_2__c, Source_Instance__r.Name 
            FROM Backlog_Component__c
        ];

        System.assertEquals(1, backlogComponents.size(), 'There should be one backlog component remaining');
        System.assertEquals(profileComponent.Name, backlogComponents[0].Component__r.Name, 'The backlog component related component name should match.');

        ProfilePermissions resultPermissions = ProfilePermissions.valueOf(backlogComponents[0]);
        ProfilePermissions.Section resultSection = resultPermissions.sections[0];
        System.assertEquals(ProfileServices.COMPONENT_TYPE_TO_CATEGORY.get(testComponentType), resultSection.apiName, 'The section API name should match.');
        System.assertEquals(1, resultSection.permissions.size(), 'There should be one permission.');
        System.assertEquals(testOtherComponentName, resultSection.permissions[0], 'The permission name should be correct.');
    }

    static testMethod void removeDeletedBacklogComponentsFromProfileData_singleBacklogSinglePermission() {
        String testProfileComponentName = 'Test Profile Component Name';
        String testOtherComponentName = 'Test Other Component Name';
        String testComponentType = ComponentServices.APEX_ALM_NAME;
        String profileJSON = generateProfileJSON(
            testProfileComponentName, 
            new Set<String>{ 'Test Instance' }, 
            new Map<String, Set<String>>{
                ProfileServices.COMPONENT_TYPE_TO_CATEGORY.get(testComponentType) => new Set<String>{ testOtherComponentName }
            }
        );

        Backlog__c backlogItem = new Backlog__c();
        insert backlogItem;
        Component__c profileComponent = new Component__c(Name = testProfileComponentName, Type__c = 'Profile');
        Component__c otherComponent = new Component__c(Name = testOtherComponentName, Type__c = testComponentType);
        insert new List<Component__c>{ profileComponent, otherComponent };
        Backlog_Component__c profileBacklogComponent = new Backlog_Component__c(
            Backlog__c = backlogItem.Id, Component__c = profileComponent.Id, Component__r = profileComponent, 
            Profile_Data_1__c = profileJSON
        );
        Backlog_Component__c deletedBacklogComponent = new Backlog_Component__c(
            Backlog__c = backlogItem.Id, Component__c = otherComponent.Id, Component__r = otherComponent
        );
        insert new List<Backlog_Component__c>{ profileBacklogComponent, deletedBacklogComponent };

        Test.startTest();

            delete deletedBacklogComponent;

        Test.stopTest();

        List<Backlog_Component__c> backlogComponents = [
            SELECT Component__r.Name, Profile_Data_1__c, Profile_Data_2__c, Source_Instance__r.Name 
            FROM Backlog_Component__c
        ];

        System.assertEquals(1, backlogComponents.size(), 'There should be one backlog component remaining');
        System.assertEquals(profileComponent.Name, backlogComponents[0].Component__r.Name, 'The backlog component related component name should match.');

        ProfilePermissions resultPermissions = ProfilePermissions.valueOf(backlogComponents[0]);
        ProfilePermissions.Section resultSection = resultPermissions.sections[0];
        System.assertEquals(ProfileServices.COMPONENT_TYPE_TO_CATEGORY.get(testComponentType), resultSection.apiName, 'The section API name should match.');
        System.assert(resultSection.permissions.isEmpty(), 'The section permissions should be empty.');
    }

    static testMethod void removeDeletedBacklogComponentsFromProfileData_multipleBacklogMultiplePermission() {
        String testComponentType = ComponentServices.APEX_ALM_NAME;

        String testProfileComponentName0 = 'Test Profile Component Name 0';
        String testOtherComponentName0 = 'Test Other Component Name 0';
        String testProfileComponentName1 = 'Test Profile Component Name 1';
        String testOtherComponentName1 = 'Test Other Component Name 1';

        String profileJSON0 = generateProfileJSON(
            testProfileComponentName0, 
            new Set<String>{ 'Test Instance' }, 
            new Map<String, Set<String>>{ 
                ProfileServices.COMPONENT_TYPE_TO_CATEGORY.get(testComponentType) => new Set<String>{ 
                    testOtherComponentName0, 
                    testOtherComponentName1
                }
            }
        );

        String profileJSON1 = generateProfileJSON(
            testProfileComponentName1, 
            new Set<String>{ 'Test Instance' }, 
            new Map<String, Set<String>>{ 
                ProfileServices.COMPONENT_TYPE_TO_CATEGORY.get(testComponentType) => new Set<String>{ 
                    testOtherComponentName0, 
                    testOtherComponentName1
                }
            }
        );

        Backlog__c backlogItem0 = new Backlog__c();
        Backlog__c backlogItem1 = new Backlog__c();
        insert new List<Backlog__c>{ backlogItem0, backlogItem1 };

        Component__c profileComponent0 = new Component__c(Name = testProfileComponentName0, Type__c = 'Profile');
        Component__c profileComponent1 = new Component__c(Name = testProfileComponentName1, Type__c = 'Profile');
        Component__c otherComponent0 = new Component__c(Name = testOtherComponentName0, Type__c = testComponentType);
        Component__c otherComponent1 = new Component__c(Name = testOtherComponentName1, Type__c = testComponentType);

        insert new List<Component__c>{ profileComponent0, profileComponent1, otherComponent0, otherComponent1 };
        Backlog_Component__c profileBacklogComponent0 = new Backlog_Component__c(
            Backlog__c = backlogItem0.Id, Component__c = profileComponent0.Id, Component__r = profileComponent0, 
            Profile_Data_1__c = profileJSON0
        );
        Backlog_Component__c profileBacklogComponent1 = new Backlog_Component__c(
            Backlog__c = backlogItem1.Id, Component__c = profileComponent1.Id, Component__r = profileComponent1, 
            Profile_Data_1__c = profileJSON1
        );
        Backlog_Component__c deletedBacklogComponent0 = new Backlog_Component__c(
            Backlog__c = backlogItem0.Id, Component__c = otherComponent0.Id, Component__r = otherComponent0
        );
        Backlog_Component__c deletedBacklogComponent1 = new Backlog_Component__c(
            Backlog__c = backlogItem1.Id, Component__c = otherComponent1.Id, Component__r = otherComponent1
        );
        insert new List<Backlog_Component__c>{ 
            profileBacklogComponent0, profileBacklogComponent1, 
            deletedBacklogComponent0, deletedBacklogComponent1 
        };

        Test.startTest();

            delete new List<Backlog_Component__c>{ deletedBacklogComponent0, deletedBacklogComponent1 };

        Test.stopTest();

        List<Backlog_Component__c> backlogComponents = [
            SELECT Component__r.Name, Profile_Data_1__c, Profile_Data_2__c, Source_Instance__r.Name 
            FROM Backlog_Component__c
            ORDER BY Component__r.Name ASC
        ];

        System.assertEquals(2, backlogComponents.size(), 'There should be one backlog components remaining');
        System.assertEquals(profileComponent0.Name, backlogComponents[0].Component__r.Name, 'The backlog component related component name should match.');
        System.assertEquals(profileComponent1.Name, backlogComponents[1].Component__r.Name, 'The backlog component related component name should match.');

        ProfilePermissions resultPermissions0 = ProfilePermissions.valueOf(backlogComponents[0]);
        ProfilePermissions.Section resultSection0 = resultPermissions0.sections[0];
        System.assertEquals(ProfileServices.COMPONENT_TYPE_TO_CATEGORY.get(testComponentType), resultSection0.apiName, 'The section API name should match.');
        System.assertEquals(1, resultSection0.permissions.size(), 'The section permissions should contain one permission.');
        System.assertEquals(testOtherComponentName1, resultSection0.permissions[0], 'The section permissions should contain the correct permission.');

        ProfilePermissions resultPermissions1 = ProfilePermissions.valueOf(backlogComponents[1]);
        ProfilePermissions.Section resultSection1 = resultPermissions1.sections[0];
        System.assertEquals(ProfileServices.COMPONENT_TYPE_TO_CATEGORY.get(testComponentType), resultSection1.apiName, 'The section API name should match.');
        System.assertEquals(1, resultSection1.permissions.size(), 'The section permissions should contain one permission.');
        System.assertEquals(testOtherComponentName0, resultSection1.permissions[0], 'The section permissions should contain the correct permission.');
    }

    private static String generateProfileJSON(String profileName, Set<String> instanceNames, Map<String, Set<String>> sectionToPermissions) {
        String profileJSON = '{"name" : "' + profileName + '", "instances" : [';

        for (String instanceName : instanceNames) {
            if (!profileJSON.endsWith('[')) {
                profileJSON += ', ';
            }
            profileJSON += '"' + instanceName + '"';
        }

        profileJSON += '], "sections" : [';

        for (String section : sectionToPermissions.keySet()) {
            if (!profileJSON.endsWith('[')) {
                profileJSON += ', ';
            }

            profileJSON += '{"apiName" : "' + section + '", "permissions" : [';

            for (String permission : sectionToPermissions.get(section)) {
                if (!profileJSON.endsWith('[')) {
                    profileJSON += ', ';
                }
                profileJSON += '"' + permission + '"';
            }

            profileJSON += ']}';
        }

        profileJSON += ']}';

        return profileJSON;
    }
}