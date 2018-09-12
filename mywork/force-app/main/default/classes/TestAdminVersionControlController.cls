@isTest
private class TestAdminVersionControlController {
    private static testMethod void getExistingRepository() {
        TestVCServices.setupRepositories();
        UnitTest.addData(TestVCServices.vcRepositories.values()).tag('All VC Repos');
        UnitTest.get('All VC Repos')
            .divide(2)
                .part('Expected Repo')
                .part('UnExpected Repo');
                
        
        VC_Repository__c expectedRepo = (VC_Repository__c) UnitTest.get('Expected Repo').getList()[0];
        ALM_Job__c expectedAlmJob;
        ALM_Application_Result__c expectedAlmJobResult;
        List<ALM_Application_Result__c> appResultsToInsert = new List<ALM_Application_Result__c>();
        
        for( VC_Repository__c repo : TestVCServices.vcRepositories.values()) {
            ALM_Job__c childJob = TestingUtils.createVCRepoSyncJob(repo.Id);
            ALM_Application_Result__c childResult = TestingUtils.buildAlmApplicationResult(DateTime.now(), 
                                                                                            DateTime.now().addDays(2), 
                                                                                            'SUCCESS', null, null, 
                                                                                            ALMJobServices.ToolType.VC_REPO_SYNC);
            childResult.ALM_Job__c = childJob.Id;
            appResultsToInsert.add(childResult);
                                                    
            if( expectedRepo.id == repo.Id ) {
                expectedAlmJob = childJob;
                expectedAlmJobResult = childResult;
            }
        }
        insert appResultsToInsert;
        
        Test.startTest();
            VCRepository actualRepo = AdminVersionControlController.getExistingRepository( expectedRepo.id );
        Test.stopTest();
        
        System.assertNotEquals(null, actualRepo, 'The actual repo should be populated');
        System.assertEquals(expectedRepo.id, actualRepo.id, 'The correct repo should be returned');
    }
    
    private static testMethod void upsertRepositoryWithAlmJob() {
        UnitTest.addData(TestVCServices.buildRepositories()).tag('All VC Repos');
        
        VC_Repository__c expectedRepo = (VC_Repository__c) UnitTest.get('All VC Repos').getList()[0];
        ALM_Job__c expectedAlmJob = TestingUtils.buildVCRepoSyncJob(null, true);
        VCRepository testVCRepoModel = new VCRepository(expectedRepo, expectedAlmJob);
        
        Test.startTest();
            Boolean destroyJob = false;
            VCRepository actualRepo = AdminVersionControlController.upsertRepositoryWithAlmJob(JSON.serialize(testVCRepoModel), destroyJob);    
        Test.stopTest();
        
        TestVCServices.assertVCRepo(actualRepo, expectedRepo);
        System.assertNotEquals( null, actualRepo.job, 'The alm Job of the repo should be set');
        ALM_Job__c actualJob = actualRepo.job.getJob();
        TestVCServices.assertVCRepoALMJob(actualJob, expectedAlmJob);
    }

    private static testMethod void setPageContext_new() {
        PageReference ref = Page.AdminVersionControl;
        ref.getParameters().put('id', AdminVersionControlController.NEW_REPO_IDENTIFIER);
        Test.setCurrentPage(ref);
        
        Test.startTest();
            AdminVersionControlController testController = new AdminVersionControlController();
            testController.setPageContext();
        Test.stopTest();
        System.assertEquals(SObjectServices.CURRENT_NAMESPACE, testController.namespace, 'The namespace should be correctly set');
        System.assertEquals(AdminVersionControlController.NEW_REPO_IDENTIFIER, testController.repoId, 'The repoid should be correctly set');
        System.assertEquals(null, testController.repoName, 'The repo name should not be set');
    }
    
    private static testMethod void setPageContext_blank() {
        PageReference ref = Page.AdminVersionControl;
        Test.setCurrentPage(ref);
        
        Test.startTest();
            AdminVersionControlController testController = new AdminVersionControlController();
            testController.setPageContext();
        Test.stopTest();
        System.assertEquals(SObjectServices.CURRENT_NAMESPACE, testController.namespace, 'The namespace should be correctly set');
        System.assertEquals(null, testController.repoId, 'The repoid should be correctly set');
        System.assertEquals(null, testController.repoName, 'The repo name should not be set');
    }

    private static testMethod void setPageContext_validRecordId() {
        TestVCServices.setupRepositories();
        UnitTest.addData(TestVCServices.vcRepositories.values()).tag('All VC Repos');
        
        VC_Repository__c expectedRepo = (VC_Repository__c) UnitTest.get('All VC Repos').getList()[0];
        PageReference ref = Page.AdminVersionControl;
        ref.getParameters().put('id', expectedRepo.Id);
        Test.setCurrentPage(ref);
        
        Test.startTest();
            AdminVersionControlController testController = new AdminVersionControlController();
            testController.setPageContext();
        Test.stopTest();
        System.assertEquals(SObjectServices.CURRENT_NAMESPACE, testController.namespace, 'The namespace should be correctly set');
        System.assertEquals(expectedRepo.Id, testController.repoId, 'The repoid should be correctly set');
        System.assertEquals(expectedRepo.Name, testController.repoName, 'The repo name should be correctly set');
    }
}
