@isTest
private with sharing class TestDXController {

    @isTest
    static void createScratchOrgRecord() {
        Backlog__c backlogItem = TestingUtils.createBacklogItem();
        String name = 'scratch-org-name';
        VC_Repository__c repo = TestingUtils.createVcRepository('createScratchOrg-repo', 'https://repo-url.com');
        String branchName = 'dev';
        Scratch_Org_Definition__c orgDef = TestingUtils.createScratchOrgDefinition('test-org-def-createScratchOrg');
        Integer durationDays = 8;
        String parentBranchName = 'Item-01234';

        Test.startTest();
            String scratchOrgId = DXController.createScratchOrgRecord(
                name, backlogItem.Id, repo.Id, branchName, orgDef.Id, durationDays, parentBranchName);
        Test.stopTest();

        List<Scratch_Org__c> scratchOrgs = [
            SELECT Id, Name, VC_Repository__c, Repository_Location__c, Backlog_Item__c, Parent_Branch_Name__c,
            Scratch_Org_Definition__c, Duration_Days__c
            FROM Scratch_Org__c
            WHERE Id = :scratchOrgId
        ];

        System.assertEquals(1, scratchOrgs.size(), 'The scratch org should have been created');
        System.assertEquals(repo.Id, scratchOrgs[0].VC_Repository__c, 'The scratch org repo should be populated');
        System.assertEquals(branchName, scratchOrgs[0].Repository_Location__c,
            'The scratch org repo location should be populated');
        System.assertEquals(backlogItem.Id, scratchOrgs[0].Backlog_Item__c,
            'The scratch org backlog item should be populated');
        System.assertEquals(orgDef.Id, scratchOrgs[0].Scratch_Org_Definition__c,
            'The scratch org scratch org definition should be populated');
        System.assertEquals(durationDays, scratchOrgs[0].Duration_Days__c,
            'The scratch org should have the correct amount of duration days');
        System.assertEquals(parentBranchName, scratchOrgs[0].Parent_Branch_Name__c,
            'The scratch org new branch name should be populated');
    }

    @isTest
    static void getScratchOrgs() {
        Backlog__c backlogItem = TestingUtils.createBacklogItem();
        Scratch_Org__c scratchOrg = new Scratch_Org__c(Backlog_Item__c = backlogItem.Id, Duration_Days__c = 8);
        Scratch_Org__c otherScratchOrg = new Scratch_Org__c(Duration_Days__c = 8);
        insert new List<Scratch_Org__c> { scratchOrg, otherScratchOrg };

        Test.startTest();
            List<DXController.ScratchOrgModel> scratchOrgs = DXController.getScratchOrgs(backlogItem.Id);
        Test.stopTest();

        System.assertEquals(1, scratchOrgs.size(), 'Only scratch orgs related to the backlog item should be returned');
        System.assertEquals(scratchOrg.Id, scratchOrgs[0].id,
            'Only scratch orgs related to the backlog item should be returned');
        System.assertEquals(true, scratchOrgs[0].isLoginable,
            'Scratch orgs created by the running user should be loginable');
    }
}
