@isTest
private class TestProfilePermissions {

    static testMethod void expandFLS() {
        ProfilePermissions permissions = new ProfilePermissions();

        List<String> section1Permissions = new List<String> {'permission1'};
        TestingUtils.buildProfilePermissionsSection(permissions, 'Some Section', section1Permissions.clone());

        TestingUtils.buildProfilePermissionsSection(permissions,
             ProfileServices.FIELD_API_NAME, new List<String> {'Backlog__c', 'Other__c'});

        Map<String, Set<String>> objectToFields = new Map<String, Set<String>> {
             'Backlog__c' => new Set<String> {'field1', 'field2'},
             'Other__c' => new Set<String> {'field3', 'field4'},
             'Other_Unselected__c' => new Set<String> {'field5', 'field6'}
        };

        Test.startTest();

            permissions.expandFLS(objectToFields);

        Test.stopTest();

        System.assertEquals(2, permissions.sections.size(), 'The number of sections should remain unchanged');
        System.assertEquals(true, section1Permissions.equals(permissions.sections[0].permissions), 'Only the FLS section should be expanded');

        Set<String> expectedPermissions = new Set<String> {'field1', 'field2', 'field3', 'field4'};

        System.assertEquals(4, permissions.sections[1].permissions.size(),
             'The FLS section should be expanded to the corresponding fields for all selections');
        System.assertEquals(true, expectedPermissions.containsAll(permissions.sections[1].permissions),
             'The FLS section should be expanded to the corresponding fields for all selections');
    }

    static testMethod void valueOf_backlogComponent() {
        ProfilePermissions expectedPermission = new ProfilePermissions();

        TestingUtils.buildProfilePermissionsSection(expectedPermission,
             'test section', new List<String> {'permission1', 'permission2'});

        String permissionsString = JSON.serialize(expectedPermission);

        Backlog_Component__c permission = TestingUtils.buildDocumentedProfile(null, null, null);
        permission.Profile_Data_1__c = permissionsString;

        Test.startTest();
            ProfilePermissions createdPermissions = ProfilePermissions.valueOf(permission);
        Test.stopTest();

        System.assertEquals(expectedPermission.sections.size(), createdPermissions.sections.size(), 'An equivalent profile permission should be created from the backlog component');
        System.assertEquals(expectedPermission.sections[0].apiName, createdPermissions.sections[0].apiName, 'An equivalent profile permission should be created from the backlog component');
        System.assertEquals(expectedPermission.sections[0].permissions.size(), createdPermissions.sections[0].permissions.size(), 'An equivalent profile permission should be created from the backlog component');
        System.assertEquals(expectedPermission.sections[0].permissions[0], createdPermissions.sections[0].permissions[0], 'An equivalent profile permission should be created from the backlog component');
        System.assertEquals(expectedPermission.sections[0].permissions[1], createdPermissions.sections[0].permissions[1], 'An equivalent profile permission should be created from the backlog component');
    }

    static testMethod void valueOf_buildComponent() {
        ProfilePermissions expectedPermission = new ProfilePermissions();

        TestingUtils.buildProfilePermissionsSection(expectedPermission,
             'test section', new List<String> {'permission1', 'permission2'});

        String permissionsString = JSON.serialize(expectedPermission);

        Build_Component__c permission = new Build_Component__c();
        permission.Profile_Data_1__c = permissionsString;

        Test.startTest();
            ProfilePermissions createdPermissions = ProfilePermissions.valueOf(permission);
        Test.stopTest();

        System.assertEquals(expectedPermission.sections.size(), createdPermissions.sections.size(), 'An equivalent profile permission should be created from the backlog component');
        System.assertEquals(expectedPermission.sections[0].apiName, createdPermissions.sections[0].apiName, 'An equivalent profile permission should be created from the backlog component');
        System.assertEquals(expectedPermission.sections[0].permissions.size(), createdPermissions.sections[0].permissions.size(), 'An equivalent profile permission should be created from the backlog component');
        System.assertEquals(expectedPermission.sections[0].permissions[0], createdPermissions.sections[0].permissions[0], 'An equivalent profile permission should be created from the backlog component');
        System.assertEquals(expectedPermission.sections[0].permissions[1], createdPermissions.sections[0].permissions[1], 'An equivalent profile permission should be created from the backlog component');
    }

    static testMethod void mergePermissions_preservesProfileName() {
        String name = 'donotchangeme';
        ProfilePermissions profile1 = new ProfilePermissions();
        profile1.name = name;

        ProfilePermissions profile2 = new ProfilePermissions();
        profile2.name = name;

        Test.startTest();

            ProfilePermissions mergedProfile = ProfilePermissions.mergePermissions(new List<ProfilePermissions>{ profile1, profile2 });

        Test.stopTest();

        System.assertEquals(name, mergedProfile.name, 'The merged profiles should retain the profile name');
    }
    
    static testMethod void mergePermissions_newSection() {
        String section1 = 's1';
        String section2 = 's2';

        ProfilePermissions profile1 = new ProfilePermissions();
        TestingUtils.buildProfilePermissionsSection(profile1, section1, new List<String> {'permission1'});

        ProfilePermissions profile2 = new ProfilePermissions();
        TestingUtils.buildProfilePermissionsSection(profile2, section2, new List<String> {'permission2'});

        Test.startTest();

            ProfilePermissions mergedProfile = ProfilePermissions.mergePermissions(new List<ProfilePermissions>{ profile1, profile2 });

        Test.stopTest();

        System.assertEquals(2, mergedProfile.sections.size(), 'The sections from all profiles should be merged');
        System.assertEquals(section1, mergedProfile.sections[0].apiName, 'The sections from all profiles should be merged');
        System.assertEquals(1, mergedProfile.sections[0].permissions.size(), 'The sections from all profiles should be merged');
        System.assertEquals(section2, mergedProfile.sections[1].apiName, 'The sections from all profiles should be merged');
        System.assertEquals(1, mergedProfile.sections[1].permissions.size(), 'The sections from all profiles should be merged');
        System.assertEquals(profile2.sections[0].permissions[0], mergedProfile.sections[1].permissions[0], 'The sections from all profiles should be merged');
    }

    static testMethod void mergePermissions_existingSection() {
        String sectionName = 's1';
        String permission1 = 'p1';
        String permission2 = 'p2';
        String permission3 = 'p3';

        ProfilePermissions profile1 = new ProfilePermissions();
        TestingUtils.buildProfilePermissionsSection(profile1, sectionName, new List<String> {permission1, permission2});

        ProfilePermissions profile2 = new ProfilePermissions();
        TestingUtils.buildProfilePermissionsSection(profile2, sectionName, new List<String> {permission1, permission3});

        Test.startTest();

            ProfilePermissions mergedProfile = ProfilePermissions.mergePermissions(new List<ProfilePermissions>{ profile1, profile2 });

        Test.stopTest();

        System.assertEquals(1, mergedProfile.sections.size(), 'The section from the other profile should be merged ');
        System.assertEquals(sectionName, mergedProfile.sections[0].apiName, 'The original section should be unchanged by the merge');
        System.assertEquals(3, mergedProfile.sections[0].permissions.size(), 'The original section should have all permissions merged');
        System.assertEquals(permission1, mergedProfile.sections[0].permissions[0], 'The section from the other profile should be merged');
        System.assertEquals(permission2, mergedProfile.sections[0].permissions[1], 'The section from the other profile should be merged');
        System.assertEquals(permission3, mergedProfile.sections[0].permissions[2], 'The section from the other profile should be merged');
    }

    static testMethod void mergePermissions_instances() {

        String instance1 = 'instance1';
        String instance2 = 'instance';

        ProfilePermissions profile1 = new ProfilePermissions();
        profile1.instances = new List<String> {instance1};

        ProfilePermissions profile2 = new ProfilePermissions();
        profile2.instances = new List<String> {instance2, instance1};

        Test.startTest();

            ProfilePermissions mergedProfile = ProfilePermissions.mergePermissions(new List<ProfilePermissions>{ profile1, profile2 });

        Test.stopTest();

        System.assertEquals(2, mergedProfile.instances.size(), 'The instances from the other profile should be merged ');
        System.assertEquals(instance1, mergedProfile.instances[0], 'The instances from the other profile should be merged ');
        System.assertEquals(instance2, mergedProfile.instances[1], 'The instances from the other profile should be merged ');
    }

    static testMethod void removePermissions() {
        Map<String, Set<String>> basePermissionSet = new Map<String, Set<String>>();
        basePermissionSet.put('Section 0', new Set<String>{ 'Permission 0-0', 'Permission 0-1' });
        basePermissionSet.put('Section 1', new Set<String>{ 'Permission 1-0', 'Permission 1-1' });
        basePermissionSet.put('Section 2', new Set<String>{ 'Permission 2-0', 'Permission 2-1' });
        basePermissionSet.put('Section 3', new Set<String>{ 'Permission 3-0', 'Permission 3-1' });

        Map<String, Set<String>> permissionsToRemove = new Map<String, Set<String>>();
        permissionsToRemove.put('Section 1', new Set<String>{});
        permissionsToRemove.put('Section 2', new Set<String>{ 'Permission 2-0' });
        permissionsToRemove.put('Section 3', new Set<String>{ 'Permission 3-0', 'Permission 3-1' });
        permissionsToRemove.put('Section 4', new Set<String>{ 'Permission 4-0', 'Permission 4-1' });
        permissionsToRemove.put('Section 5', new Set<String>{ 'Permission 0-0', 'Permission 0-1' });

        ProfilePermissions permissions = new ProfilePermissions(basePermissionSet);

        Test.startTest();

            try {
                permissions.removePermissions(permissionsToRemove);
            } catch (Exception e) {
                System.assert(false, 'No exceptions should be thrown.');
            }

        Test.stopTest();

        System.assertEquals(4, permissions.sections.size(), 'There should still be four sections.');

        Map<String, ProfilePermissions.Section> sectionMap = permissions.getSectionMap();

        System.assert(sectionMap.containsKey('Section 0'), 'Section 0 should still exist.');
        System.assert(new Set<String>(sectionMap.get('Section 0').permissions).contains('Permission 0-0'), 'Permission 0-0 should still exist.');
        System.assert(new Set<String>(sectionMap.get('Section 0').permissions).contains('Permission 0-1'), 'Permission 0-1 should still exist.');

        System.assert(sectionMap.containsKey('Section 1'), 'Section 1 should still exist.');
        System.assert(new Set<String>(sectionMap.get('Section 1').permissions).contains('Permission 1-0'), 'Permission 1-0 should still exist.');
        System.assert(new Set<String>(sectionMap.get('Section 1').permissions).contains('Permission 1-1'), 'Permission 1-1 should still exist.');

        System.assert(sectionMap.containsKey('Section 2'), 'Section 2 should still exist.');
        System.assert(!(new Set<String>(sectionMap.get('Section 2').permissions).contains('Permission 2-0')), 'Permission 1-0 should not still exist.');
        System.assert(new Set<String>(sectionMap.get('Section 2').permissions).contains('Permission 2-1'), 'Permission 1-1 should still exist.');

        System.assert(sectionMap.containsKey('Section 3'), 'Section 3 should still exist.');
        System.assert(sectionMap.get('Section 3').permissions.isEmpty(), 'Section 3 should be empty.');
    }
}