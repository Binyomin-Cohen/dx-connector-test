@isTest
private with sharing class TestDXCreateScratchOrgRequest {

    @isTest static void createScratchOrgDefinitionMap_noTemplateDefined() {
        Test.startTest();
            Map<String, Object> scratchOrgDef = DXCreateScratchOrgRequest.createScratchOrgDefinitionMap(null);
        Test.stopTest();

        System.assertEquals(true, scratchOrgDef.isEmpty(), 
            'an empty map should be returned when no configuration is specified');
    }

    @isTest static void createScratchOrgDefinitionMap_onlyIncludeDefinedFields() {
        Scratch_Org_Definition__c definitionSObject = new Scratch_Org_Definition__c();
        definitionSObject.Description__c = 'some description';

        Test.startTest();
            Map<String, Object> scratchOrgDef = DXCreateScratchOrgRequest.createScratchOrgDefinitionMap(definitionSObject);
        Test.stopTest();

        System.assertEquals(1, scratchOrgDef.size(), 'Only config options with values should be returned');
        String descriptionKey = DXCreateScratchOrgRequest.SCRATCH_DEF_FIELDS_TO_KEYS.get(
            Schema.Scratch_Org_Definition__c.Description__c);
        System.assertEquals(definitionSObject.Description__c, scratchOrgDef.get(descriptionKey),
             'Only config options with values should be returned');
    }

    @isTest static void createScratchOrgDefinitionMap_hasSampleDataValue() {
        Scratch_Org_Definition__c definitionSObject = new Scratch_Org_Definition__c();
        definitionSObject.Has_Sample_Data__c = true;

        Test.startTest();
            Map<String, Object> scratchOrgDef = DXCreateScratchOrgRequest.createScratchOrgDefinitionMap(definitionSObject);
        Test.stopTest();

        System.assertEquals(1, scratchOrgDef.size(), 'Only config options with values should be returned');
        String hasSampleDataKey = DXCreateScratchOrgRequest.SCRATCH_DEF_OTHER_FIELDS_MAPPING.get(
            Schema.Scratch_Org_Definition__c.Has_Sample_Data__c);
        System.assertEquals(definitionSObject.Has_Sample_Data__c, scratchOrgDef.get(hasSampleDataKey),
             'The boolean option should only be returned when it is true');
    }
    
    @isTest static void createScratchOrgDefinitionMap_hasSampleDataFalseValue() {
        Scratch_Org_Definition__c definitionSObject = new Scratch_Org_Definition__c();
        definitionSObject.Has_Sample_Data__c = false;

        Test.startTest();
            Map<String, Object> scratchOrgDef = DXCreateScratchOrgRequest.createScratchOrgDefinitionMap(definitionSObject);
        Test.stopTest();

        System.assertEquals(0, scratchOrgDef.size(), 'The boolean option should only be returned when it is true');
    }


    @isTest static void createScratchOrgDefinitionMap_hasFeatures() {
        Scratch_Org_Definition__c definitionSObject = new Scratch_Org_Definition__c();
        definitionSObject.Features__c = 'one;two';

        Test.startTest();
            Map<String, Object> scratchOrgDef = DXCreateScratchOrgRequest.createScratchOrgDefinitionMap(definitionSObject);
        Test.stopTest();

        System.assertEquals(1, scratchOrgDef.size(), 'Only config options with values should be returned');
        String featureKey = DXCreateScratchOrgRequest.SCRATCH_DEF_OTHER_FIELDS_MAPPING.get(
            Schema.Scratch_Org_Definition__c.Features__c);
        List<String> features = (List<String>)scratchOrgDef.get(featureKey); 
        System.assertEquals(2, features.size(),
             'The features list should be populated with all selected features');
        System.assertEquals(true, features.contains('one'),
             'The features list should be populated with all selected features');
        System.assertEquals(true, features.contains('two'),
             'The features list should be populated with all selected features');
    }
    
    @isTest static void createScratchOrgDefinitionMap_hasOrgPreferencesEnabled() {
        Scratch_Org_Definition__c definitionSObject = new Scratch_Org_Definition__c();
        definitionSObject.Enabled_Org_Preferences__c = 'one;two';

        Test.startTest();
            Map<String, Object> scratchOrgDef = DXCreateScratchOrgRequest.createScratchOrgDefinitionMap(definitionSObject);
        Test.stopTest();

        System.assertEquals(1, scratchOrgDef.size(), 'Only config options with values should be returned');
        String enabledKey = DXCreateScratchOrgRequest.SCRATCH_DEF_OTHER_FIELDS_MAPPING.get(
            Schema.Scratch_Org_Definition__c.Enabled_Org_Preferences__c);
        Map<String, List<String>> preferences =
             (Map<String, List<String>>)scratchOrgDef.get(DXCreateScratchOrgRequest.ORG_PREFERENCES); 
        System.assertEquals(2, preferences.size(),
             'The preferences object should be populated with enabled and disabled lists');
        System.assertEquals(true, preferences.containsKey(enabledKey),
             'The preferences object should be populated with enabled list');
        System.assertEquals(2, preferences.get(enabledKey).size(),
             'The enabled preferences list should be populated from the enabled field');
        System.assertEquals(true, preferences.get(enabledKey).contains('one'),
             'The enabled preferences list should be populated from the enabled field');
        System.assertEquals(true, preferences.get(enabledKey).contains('two'),
             'The enabled preferences list should be populated from the enabled field');
    }

    @isTest static void createScratchOrgDefinitionMap_hasOrgPreferencesDisabled() {
        Scratch_Org_Definition__c definitionSObject = new Scratch_Org_Definition__c();
        definitionSObject.Disabled_Org_Preferences__c = 'one;two';

        Test.startTest();
            Map<String, Object> scratchOrgDef = DXCreateScratchOrgRequest.createScratchOrgDefinitionMap(definitionSObject);
        Test.stopTest();

        System.assertEquals(1, scratchOrgDef.size(), 'Only config options with values should be returned');
        String disabledKey = DXCreateScratchOrgRequest.SCRATCH_DEF_OTHER_FIELDS_MAPPING.get(
            Schema.Scratch_Org_Definition__c.Disabled_Org_Preferences__c);
        Map<String, List<String>> preferences = 
            (Map<String, List<String>>)scratchOrgDef.get(DXCreateScratchOrgRequest.ORG_PREFERENCES); 
        System.assertEquals(2, preferences.size(),
             'The preferences object should be populated with enabled and disabled lists');
        System.assertEquals(true, preferences.containsKey(disabledKey),
             'The preferences object should be populated with disabled list');
        System.assertEquals(2, preferences.get(disabledKey).size(),
             'The disabled preferences list should be populated from the disabled field');
        System.assertEquals(true, preferences.get(disabledKey).contains('one'),
             'The disabled preferences list should be populated from the disabled field');
        System.assertEquals(true, preferences.get(disabledKey).contains('two'),
             'The disabled preferences list should be populated from the disabled field');
    }

    @isTest static void isCreatingNewbranch() {
       
        Scratch_Org_Definition__c definitionSObject = new Scratch_Org_Definition__c(
            Edition__c = 'Enterprise'
        );
        insert definitionSObject;

        Scratch_Org__c sOrg = new Scratch_Org__c(
            Parent_Branch_Name__c = 'Parent',
            Repository_Location__c = 'BranchToBeCreated',
            Scratch_Org_Definition__c = definitionSObject.Id
        );

        Scratch_Org__c sOrg2 = new Scratch_Org__c(
            Repository_Location__c = 'BranchToBeCreated',
            Scratch_Org_Definition__c = definitionSObject.Id
        );

        System.assertEquals(true, DXCreateScratchOrgRequest.isCreatingNewBranch(sOrg),
             'When parent branch name is defined, it should be determined that a new branch should be created');
        System.assertEquals(false, DXCreateScratchOrgRequest.isCreatingNewBranch(sOrg2),
             'When parent branch name is not defined, it should be determined that a new branch should not be created');
    }
    
}
