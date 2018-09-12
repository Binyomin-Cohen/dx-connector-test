@isTest
public class TestVCServices {
    private static final User TEST_KEY_OWNER = TestingUtils.ADMIN_USER;
    private static final String TEST_KEY_OWNER_ID = TEST_KEY_OWNER.Id;
    private static final String TEST_REPOSITORY_URL = 'https://www.example.com/test-repository';
    private static final String TEST_LIST_FAILURE_REASON = 'Test Failure Reason';
    private static final String GIT_REPO_NAME = 'git-repo';
    private static final String BITBUCKET_REPO_NAME = 'bitbucket-repo';

    @TestVisible
    private static Map<Id, VC_Repository__c> vcRepositories;

    @TestVisible
    private static void setupRepositories() {
        List<VC_Repository__c> reposToInsert = buildRepositories();
        insert reposToInsert;
        vcRepositories = getAllCreatedReposAsMap();
    }
    
    @TestVisible
    private static List<VC_Repository__c> buildRepositories() {
        List<VC_Repository__c> testRepos = new List<VC_Repository__c>();
        testRepos.add(TestingUtils.buildVcRepository(GIT_REPO_NAME, 'http://www.git.com', 'GitHub', 'GitTest'));
        testRepos.add(TestingUtils.buildVcRepository(BITBUCKET_REPO_NAME, 'http://www.bitbucket.com', 'BitBucket', 'BitTest'));
        
        return testRepos;
    }
    
    private static Map<Id, VC_Repository__c> getAllCreatedReposAsMap() {
        return new Map<Id, VC_Repository__c>([SELECT Id, Name, 
                                                               Organization_Name__c, Repository_URL__c, 
                                                               Host__c, Sync_Revisions_From__c, Source_Format__c
                                                        FROM VC_Repository__c]);
    }
    
    
    private static testMethod void validateGitConnection_noPrivateSettings() {
        Test.setMock(HttpCalloutMock.class, new MockVCAPI(MockVCAPI.setupGitListSuccessResponse(null)));

        Blob testManagementKey = Crypto.generateAesKey(SSHServices.MANAGEMENT_ENCRYPTION_KEY_BIT_WIDTH);
        TestingUtils.createSSHUserKeypair(TestingUtils.TEST_PUBLIC_KEY, TestingUtils.TEST_PRIVATE_KEY, TestingUtils.TEST_PASSPHRASE, testManagementKey);
        VC_Repository__c vcRepository = new VC_Repository__c(
            Repository_URL__c = TEST_REPOSITORY_URL
        );
        insert vcRepository;
        List<VCRepository> actualReposWithValidations = new List<VCRepository>();

        Test.startTest();

            try {
                VCServices.validateGitConnection(TEST_KEY_OWNER_ID, vcRepository.id);
                System.assert(false, 'An exception should be thrown when no private settings exist.');
            } catch (Exception e) {
                System.assertEquals(System.Label.SSH_User_Key_Retrieval_Error + ' Exception type: System.SecurityException', e.getMessage(), 'The proper exception should be thrown when no private settings exist.');
                actualReposWithValidations = VCServices.loadVCReposWithValidationsForUser();
            }

        Test.stopTest();
        System.assertEquals(1, actualReposWithValidations.size(),'One validation attempt, grouped by repo, should exist');
        VCRepository actualRepoRecord = actualReposWithValidations[0];
        System.assertEquals(vcRepository.Id, actualRepoRecord.id, 'One validation attempt should exist for this repo');
        System.assertNotEquals(null, actualRepoRecord.validation, 'Only one validation record should exist for this repo');
        VCRepository.Validation actualValidation = actualRepoRecord.validation;
        System.assert(!actualValidation.isSuccessful, 'The validation attempt should not be successful');
        System.assertEquals(actualValidation.externalId, UserInfo.getUserId() + vcRepository.Id, 'The external Id should be correctly set');
        System.assertNotEquals(null, actualValidation.error, 'The validation error should not be blank');
        System.assert(actualValidation.error.contains(System.Label.SSH_User_Key_Retrieval_Error), 'The validation error should contain the correct error');
    }

    private static testMethod void validateGitConnection_noKeypairExists() {
        Test.setMock(HttpCalloutMock.class, new MockVCAPI(MockVCAPI.setupGitListSuccessResponse(null)));

        Blob testManagementKey = Crypto.generateAesKey(SSHServices.MANAGEMENT_ENCRYPTION_KEY_BIT_WIDTH);
        TestingUtils.createSSHPrivateSettings(testManagementKey);
        VC_Repository__c vcRepository = new VC_Repository__c(
            Repository_URL__c = TEST_REPOSITORY_URL
        );
        insert vcRepository;
        List<VCRepository> actualReposWithValidations = new List<VCRepository>();

        Test.startTest();
            try {
                VCServices.validateGitConnection(TEST_KEY_OWNER_ID, vcRepository.Id);

                System.assert(false, 'An exception should be thrown when no keypair exists.');
            } catch (Exception e) {
                System.assertEquals(System.Label.VC_Keypair_Retrieval_Error, e.getMessage(), 'The proper exception should be thrown when no keypair exists.');
                actualReposWithValidations = VCServices.loadVCReposWithValidationsForUser();
            }
        Test.stopTest();

        System.assertEquals(1, actualReposWithValidations.size(),'One validation attempt, grouped by repo, should exist');
        VCRepository actualRepo = actualReposWithValidations[0];
        System.assertEquals(vcRepository.Id, actualRepo.id, 'One validation attempt should exist for this repo');
        System.assertNotEquals(null, actualRepo.validation, 'A validation record should exist for this repo');

        VCRepository.Validation actualValidation = actualRepo.validation;
        System.assert(!actualValidation.isSuccessful, 'The validation attempt should not be successful');
        System.assertEquals(actualValidation.externalId, UserInfo.getUserId() + vcRepository.Id, 'The external Id should be correctly set');
        System.assertNotEquals(null, actualValidation.error, 'The validation error should not be blank');
        System.assert(actualValidation.error.contains(System.Label.VC_Keypair_Retrieval_Error), 'The validation error should contain the correct error');
    }

    private static testMethod void validateGitConnection_noRepositoryRecordExists() {
        Test.setMock(HttpCalloutMock.class, new MockVCAPI(MockVCAPI.setupGitListSuccessResponse(null)));

        Blob testManagementKey = Crypto.generateAesKey(SSHServices.MANAGEMENT_ENCRYPTION_KEY_BIT_WIDTH);
        TestingUtils.createSSHPrivateSettings(testManagementKey);
        TestingUtils.createSSHUserKeypair(TestingUtils.TEST_PUBLIC_KEY, TestingUtils.TEST_PRIVATE_KEY, TestingUtils.TEST_PASSPHRASE, testManagementKey);

        Test.startTest();

            try {
                VCServices.validateGitConnection(TEST_KEY_OWNER_ID, null);

                System.assert(false, 'An exception should be thrown when no repository record exists.');
            } catch (Exception e) {
                System.assertEquals(System.Label.VC_Repository_Retrieval_Error, e.getMessage(), 'The proper exception should be thrown when no repository record exists.');
                List<VCRepository> actualRepos = VCServices.loadVCReposWithValidationsForUser();
                System.assertEquals(0, actualRepos.size(), 'The repo should exist');
            }

        Test.stopTest();
    }

    private static testMethod void validateGitConnection_nullListResponse() {
        Test.setMock(HttpCalloutMock.class, new MockVCAPI(null));

        Blob testManagementKey = Crypto.generateAesKey(SSHServices.MANAGEMENT_ENCRYPTION_KEY_BIT_WIDTH);
        TestingUtils.createSSHPrivateSettings(testManagementKey);
        TestingUtils.createSSHUserKeypair(TestingUtils.TEST_PUBLIC_KEY, TestingUtils.TEST_PRIVATE_KEY, TestingUtils.TEST_PASSPHRASE, testManagementKey);
        VC_Repository__c vcRepository = new VC_Repository__c(
            Repository_URL__c = TEST_REPOSITORY_URL
        );
        insert vcRepository;
        List<VCRepository> actualReposWithValidations = new List<VCRepository>();

        Test.startTest();
            try {
                VCServices.validateGitConnection(TEST_KEY_OWNER_ID, vcRepository.Id);

                System.assert(false, 'An exception should be thrown when a null list response is returned.');
            } catch (Exception e) {
                System.assertEquals(VCServices.BAD_URL, e.getMessage(), 'The proper exception should be thrown when a null list response is returned.');
                actualReposWithValidations = VCServices.loadVCReposWithValidationsForUser();
            }
        Test.stopTest();

        System.assertEquals(1, actualReposWithValidations.size(), 'One validation attempt, grouped by repo, should exist');
        VCRepository actualRepo = actualReposWithValidations[0];
        System.assertEquals(vcRepository.Id, actualRepo.id, 'One validation attempt should exist for this repo');
        System.assertNotEquals(null, actualRepo.validation, 'A validation record should exist for this repo');
        VCRepository.Validation actualValidation = actualRepo.validation;
        System.assert(!actualValidation.isSuccessful, 'The validation attempt should not be successful');
        System.assertEquals(actualValidation.externalId, UserInfo.getUserId() + vcRepository.Id, 'The external Id should be correctly set');
        System.assertNotEquals(null, actualValidation.error, 'The validation error should not be blank');
        System.assert(actualValidation.error.contains(VCServices.BAD_URL), 'The validation error should contain the correct error');
    }

    private static testMethod void validateGitConnection_successListResponse() {
        Test.setMock(HttpCalloutMock.class, new MockVCAPI(MockVCAPI.setupGitListSuccessResponse(null)));

        Blob testManagementKey = Crypto.generateAesKey(SSHServices.MANAGEMENT_ENCRYPTION_KEY_BIT_WIDTH);
        TestingUtils.createSSHPrivateSettings(testManagementKey);
        TestingUtils.createSSHUserKeypair(TestingUtils.TEST_PUBLIC_KEY, TestingUtils.TEST_PRIVATE_KEY, TestingUtils.TEST_PASSPHRASE, testManagementKey);
        VC_Repository__c vcRepository = new VC_Repository__c(
            Repository_URL__c = TEST_REPOSITORY_URL
        );
        insert vcRepository;
        List<VCRepository> actualReposWithValidations = new List<VCRepository>();
        Test.startTest();

            VCServices.GitListResponse connectionResponse = VCServices.validateGitConnection(TEST_KEY_OWNER_ID, vcRepository.Id);
            actualReposWithValidations = VCServices.loadVCReposWithValidationsForUser();

        Test.stopTest();

        System.assert(connectionResponse.isSuccess, 'The validation should be successful.');
        System.assert(String.isBlank(connectionResponse.failureReason), 'The validation should have no failure reason.');
        System.assertEquals(1, actualReposWithValidations.size(),'One validation attempt, grouped by repo, should exist');
        VCRepository actualRepo = actualReposWithValidations[0];
        System.assertEquals(vcRepository.Id, actualRepo.id, 'One validation attempt should exist for this repo');
        System.assertNotEquals(null, actualRepo.validation, 'A validation record should exist for this repo');

        VCRepository.Validation actualValidation = actualRepo.validation;
        System.assert(actualValidation.isSuccessful, 'The validation attempt should be successful');
        System.assertEquals(actualValidation.externalId, UserInfo.getUserId() + vcRepository.Id, 'The external Id should be correctly set');
        System.assertEquals(null, actualValidation.error, 'The validation error should be blank');
    }

    private static testMethod void validateGitConnection_successListResponseMultipleTimes() {
        Test.setMock(HttpCalloutMock.class, new MockVCAPI(MockVCAPI.setupGitListSuccessResponse(null)));

        Blob testManagementKey = Crypto.generateAesKey(SSHServices.MANAGEMENT_ENCRYPTION_KEY_BIT_WIDTH);
        TestingUtils.createSSHPrivateSettings(testManagementKey);
        TestingUtils.createSSHUserKeypair(TestingUtils.TEST_PUBLIC_KEY, TestingUtils.TEST_PRIVATE_KEY, TestingUtils.TEST_PASSPHRASE, testManagementKey);
        VC_Repository__c vcRepository = new VC_Repository__c( Name = 'TestRepoName',
            Repository_URL__c = TEST_REPOSITORY_URL
        );
        insert vcRepository;
        List<VCRepository> actualReposWithValidations = new List<VCRepository>();
        //Create an existing vc validation record
        Boolean doInsert = false;
        VC_Repository_Validation__c duplicateVCRV = TestingUtils.createVcRepositoryValidation(vcRepository, doInsert);
        duplicateVCRV.SuccessfulValidation__c = false;
        duplicateVCRV.ValidationError__c = 'Some random error text';
        insert duplicateVCRV;

        Test.startTest();
            VCServices.GitListResponse connectionResponse = VCServices.validateGitConnection(TEST_KEY_OWNER_ID, vcRepository.Id);
            actualReposWithValidations = VCServices.loadVCReposWithValidationsForUser();
        Test.stopTest();

        System.assert(connectionResponse.isSuccess, 'The validation should be successful.');
        System.assert(String.isBlank(connectionResponse.failureReason), 'The validation should have no failure reason.');
        System.assertEquals(1, actualReposWithValidations.size(),'One validation attempt, grouped by repo, should exist');
        VCRepository actualRepo = actualReposWithValidations[0];
        System.assertEquals(vcRepository.Id, actualRepo.id, 'One validation attempt should exist for this repo');
        System.assertNotEquals(null, actualRepo.validation, 'A validation record should exist for this repo');

        VCRepository.Validation actualValidation = actualRepo.validation;
        System.assert(actualValidation.isSuccessful, 'The validation attempt should be successful');
        System.assertEquals(actualValidation.externalId, UserInfo.getUserId() + vcRepository.Id, 'The external Id should be correctly set');
        System.assertEquals(null, actualValidation.error, 'The validation error should be blank');
    }

    private static testMethod void validateGitConnection_failureListResponse() {
        String failureResponse = MockVCAPI.setupGitListFailureResponse(TEST_LIST_FAILURE_REASON);
        Test.setMock(HttpCalloutMock.class, new MockVCAPI(failureResponse));

        Blob testManagementKey = Crypto.generateAesKey(SSHServices.MANAGEMENT_ENCRYPTION_KEY_BIT_WIDTH);
        TestingUtils.createSSHPrivateSettings(testManagementKey);
        TestingUtils.createSSHUserKeypair(TestingUtils.TEST_PUBLIC_KEY, TestingUtils.TEST_PRIVATE_KEY, TestingUtils.TEST_PASSPHRASE, testManagementKey);
        VC_Repository__c vcRepository = new VC_Repository__c(
            Repository_URL__c = TEST_REPOSITORY_URL
        );
        insert vcRepository;
        List<VCRepository> actualReposWithValidations = new List<VCRepository>();
        Test.startTest();

            VCServices.GitListResponse connectionResponse = VCServices.validateGitConnection(TEST_KEY_OWNER_ID, vcRepository.Id);
            actualReposWithValidations = VCServices.loadVCReposWithValidationsForUser();
        Test.stopTest();

        System.assertEquals(false, connectionResponse.isSuccess, 'The validation should be a failure.');
        System.assertEquals(TEST_LIST_FAILURE_REASON, connectionResponse.failureReason, 'The validation should have the proper failure reason.');

        System.assertEquals(1, actualReposWithValidations.size(),'One validation attempt, grouped by repo, should exist');
        VCRepository actualRepo = actualReposWithValidations[0];
        System.assertEquals(vcRepository.Id, actualRepo.id, 'One validation attempt should exist for this repo');
        System.assertNotEquals(null, actualRepo.validation, 'A validation record should exist for this repo');
        VCRepository.Validation actualValidation = actualRepo.validation;
        System.assert(!actualValidation.isSuccessful, 'The validation attempt should not be successful');
        System.assertEquals(actualValidation.externalId, UserInfo.getUserId() + vcRepository.Id, 'The external Id should be correctly set');
        VCServices.GitListResponse mockListResponse = (VCServices.GitListResponse)JSON.deserialize(failureResponse, VCServices.GitListResponse.class);
        System.assertEquals(mockListResponse.failureReason, actualValidation.error, 'The validation error should be set correctly');
        System.assertEquals(Datetime.newInstance(mockListResponse.dateTimeEpoch) , actualValidation.validationDate, 'The validation error should be set correctly');
    }

    private static testMethod void makeCommitRequest() {
        Test.setMock(HttpCalloutMock.class, new MockWebAssemblerAPI(MockWebAssemblerAPI.GIT_COMMIT_SUCCESS_ACTION));
        VC_Commit__c vcCommit;
        System.runAs(TEST_KEY_OWNER) {
            vcCommit = TestingUtils.setupVCCommit();
        }

        Test.startTest();

            VCServices.CommitResult result;
            System.runAs(TEST_KEY_OWNER) {
                result = VCServices.makeCommitRequest(vcCommit);
            }

        Test.stopTest();

        System.assertEquals(MockWebAssemblerAPI.STATUS_RESULT, result.result,
                            'The commit should be updated with the status from the commit response');
        System.assertEquals(MockWebAssemblerAPI.JOB_ID, result.jobId, 'The results should have the correct UUID');

        VC_Commit__c updatedCommit = [SELECT Id, Status__c, UUID__c, Commit_Owner__c FROM VC_Commit__c WHERE Id = :vcCommit.Id];
        System.assertEquals(TEST_KEY_OWNER.Username, updatedCommit.Commit_Owner__c,
                        'The commit owner should be set with the CreatedBy username');
        System.assertEquals(MockWebAssemblerAPI.STATUS_RESULT, updatedCommit.Status__c,
                         'The commit record should be updated with the status from the commit response');
        System.assertEquals(MockWebAssemblerAPI.JOB_ID, updatedCommit.UUID__c,
                         'The commit record should be updated with the job id from the commit response');
    }

    private static testMethod void getVCRepositories() {
        setupRepositories();

        Test.startTest();
        List<VCRepository> repos = VCServices.getVCRepositories();
        Test.stopTest();

        System.assertEquals(vcRepositories.size(), repos.size(),
                'The size of the list of repo wrappers should match that of the list of inserted repositories.');

        for (VCRepository repo : repos) {
            if (vcRepositories.containsKey(repo.id)) {
                VC_Repository__c insertedRepo = vcRepositories.get(repo.id);
                System.assertEquals(insertedRepo.Name, repo.name,
                        'The wrapper name should match the record name of the same Id.');
                System.assertEquals(insertedRepo.Repository_URL__c, repo.repositoryUrl,
                        'The wrapper repositoryUrl should match the record repositoryUrl of the same Id.');
            } else {
                System.assert(false,
                        'The inserted repositories should contain the Id of the repositoryUrl wrapper.');
            }
        }
    }

    private static testMethod void syncRepositoriesFailure() {
        TestingUtils.VCRepoSyncSetup repoSetup = TestingUtils.setupSyncRepoJobs();

        MockVCAPI vcAPI = new MockVCAPI('unusedTestResponseBody', ALMRestServices.HTTP_NOT_FOUND);
        Test.setMock(HttpCalloutMock.class, vcAPI);

        Test.startTest();
            VCServices.syncRepositories(repoSetup.getJobIds());
        Test.stopTest();

            // JOB STATUS should be SCHEDULED
        List<ALM_Job__c> syncRepoJobsFromDB = [
                SELECT Id, Status__c
                FROM ALM_Job__c
                WHERE Id in :repoSetup.getJobIds()];

        for(ALM_job__c actualJob: syncRepoJobsFromDB){
            System.assertEquals ( SCANServices.TOOL_STATUS_SCHEDULED, actualJob.Status__c, 'Status of actual job should be scheduled');
        }

    }

    private static testMethod void syncRepositories_emptyDates() {
        Datetime TEST_DATE = Date.newInstance(2016, 2, 17);

        TestingUtils.VCRepoSyncSetup repoSetup = TestingUtils.setupSyncRepoJobs();
        List<VC_Repository__c> repos = repoSetup.getReposList();
        repos[0].Sync_Revisions_From__c = TEST_DATE;
        repos[0].Last_Sync_Date__c = null;

        repos[1].Sync_Revisions_From__c = null;
        repos[1].Last_Sync_Date__c = TEST_DATE;
        update repos;

        MockVCAPI vcAPI = new MockVCAPI('unusedTestResponseBody');
        Test.setMock(HttpCalloutMock.class, vcAPI);

        Test.startTest();
            VCServices.syncRepositories(repoSetup.getJobIds());
        Test.stopTest();

        VCRepoSyncRequest actualSyncRequest =
            (VCRepoSyncRequest) JSON.deserialize(vcAPI.requestBody, VCRepoSyncRequest.class);

        Map<Id, Long> syncRepoDateTimesByRepoId = new Map<Id, Long>();
        for (VCRepoSyncRequest.VCRepoSyncDetails detail : actualSyncRequest.reposToSync) {
            syncRepoDateTimesByRepoId.put(detail.repoId, detail.syncDateFrom);
        }

        Long TEST_DATE_LONG = TEST_DATE.getTime();
        System.assertEquals(TEST_DATE_LONG, syncRepoDateTimesByRepoId.get(repos[0].Id),
                            'the repo details from the request should have a syncRepoDate populated');
        System.assertEquals(TEST_DATE_LONG, syncRepoDateTimesByRepoId.get(repos[1].Id),
                            'the repo details from the request should have a syncRepoDate populated');
    }

    private static testMethod void syncRepositories() {

        TestingUtils.VCRepoSyncSetup repoSetup = TestingUtils.setupSyncRepoJobs();

        MockVCAPI vcAPI = new MockVCAPI('unusedTestResponseBody');
        Test.setMock(HttpCalloutMock.class, vcAPI);

        Test.startTest();
            VCServices.syncRepositories(repoSetup.getJobIds());
        Test.stopTest();

        System.assertEquals(vcAPI.mockResponseStatusCode, 200,
                            'The HTTP request should not throw an error');

        VCRepoSyncRequest actualSyncRequest =
            (VCRepoSyncRequest) JSON.deserialize(vcAPI.requestBody, VCRepoSyncRequest.class);

        // OAUTH REFRESH
        OAuthServices.AppSettings settings = repoSetup.getOauthSettings();
        System.assertEquals(settings.consumerKey, actualSyncRequest.clientId,
                'The client id in the request body should match the one in the oauth settings');

        System.assertEquals(settings.consumerSecret, actualSyncRequest.clientSecret,
                'The client secret in the request body should match the one in the oauth settings');

        Auth_User__c authUser = repoSetup.getAuthUser();
        System.assertEquals(authUser.Refresh_Token__c , actualSyncRequest.sightlineRefreshToken,
                'The sightline refresh token in the request body should match the refresh token of the auth user');

        System.assertEquals(authUser.Instance_URL__c  + VCServices.SOAP_ENDPOINT,
                            actualSyncRequest.sightlineEndpoint,
                            'The sightline endpoint in the request body should match the endpoint of the auth user');


        // REPO DETAILS
        List<ALM_Job__c> repoSyncJobs = repoSetup.getRepoSyncJobs();
        System.assertEquals( repoSyncJobs.size(), actualSyncRequest.reposToSync.size(),
                'The number of repos in the request should be correct');

        Map<Id, VCRepoSyncRequest.VCRepoSyncDetails> actualRepoSyncJobs = new Map<Id, VCRepoSyncRequest.VCRepoSyncDetails>();
        Map<Id, VC_Repository__c> repoIdToRepoMap = repoSetup.getRepoIdToRepoMap();

        for (VCRepoSyncRequest.VCRepoSyncDetails actualRepo : actualSyncRequest.reposToSync) {

            actualRepoSyncJobs.put(actualRepo.almJobId, actualRepo);

            ALM_Job__c expectedJob =  repoSetup.getRepoSyncJobIdsToJobs().get(actualRepo.almJobId);

			VC_Repository__c expectedRepo = repoIdToRepoMap.get(actualRepo.repoId);
            System.assertEquals( expectedJob.VC_Repo__c, actualRepo.repoId, 'repo id should be correct' );
            System.assertEquals( expectedRepo.Repository_URL__c, actualRepo.repoUrl, 'repo url should be correct' );

            // The syncDateFrom that we send in the request should be the later of Sync_Revisions_From__c and Last_Sync_Date__c
            Long expectedSyncDateFrom = (expectedRepo.Sync_Revisions_From__c > expectedRepo.Last_Sync_Date__c) ?
                                            expectedRepo.Sync_Revisions_From__c.getTime() :
                                            expectedRepo.Last_Sync_Date__c.getTime();

            System.assertEquals( expectedSyncDateFrom, actualRepo.syncDateFrom,
                    'repo sync date from should be correct' );


            // SSH
            Map<String, String> keysAndPassphrase = SSHServices.retrieveKeysAndPassphrase(UserInfo.getUserId());
            System.assertEquals( keysAndPassphrase.get(SSHServices.PUBLIC_KEY), actualRepo.publicKey, 'Public key should be set properly in request body');
            System.assertEquals( keysAndPassphrase.get(SSHServices.PRIVATE_KEY) , actualRepo.privateKey, 'Private key should be set properly in request body');
            System.assertEquals( keysAndPassphrase.get(SSHServices.PASS_PHRASE), actualRepo.passPhrase, 'Pass phrase should be set properly in request body ');


        }
       //JOB IDS
        System.assertEquals(repoSetup.getJobIds(), actualRepoSyncJobs.keySet(),
                            'The request body should contain all the Repo Sync Job Ids');

       // JOB STATUS should be QUEUED
        List<ALM_Job__c> syncRepoJobsFromDB = [SELECT Id, Status__c
                                         FROM ALM_Job__c WHERE Id in :actualRepoSyncJobs.keySet()];
        for(ALM_job__c actualJob: syncRepoJobsFromDB){
        		System.assertEquals ( SCANServices.TOOL_STATUS_QUEUED, actualJob.Status__c, 'Status of actual job should be queued');
        }
    }

    private static testMethod void upsertRepository_createRepository() {
        String name = 'git-bit-repo';
        String repoUrl = 'https://www.git-bit-repo.org';
        String host = 'GitHub';
        String orgName = 'ForTesting';
        String metadataPath = 'some/path';
        VCRepository repoWrapper;

        Test.startTest();

            try {
                repoWrapper = VCServices.upsertRepository('', name, repoUrl, host, orgName, metadataPath);
            } catch (Exception e) {
                System.assert(false,
                        'Should not have thrown an exception because the name, repoUrl, host, and orgName are valid Strings.');
            }

        Test.stopTest();

        List<VC_Repository__c> repoRecords = [SELECT Id, Name, Repository_URL__c, Host__c, 
                                                Organization_Name__c, SFDC_Metadata_Path__c, Source_Format__c
                                               FROM VC_Repository__c
                                               WHERE Name=:name AND Repository_URL__c=:repoUrl];

        System.assert(repoRecords.size() != 0,
                'There should be a record inserted into the database with the specific name and repository url.');

        System.assertEquals(repoWrapper.id, repoRecords[0].Id,
                'The repoWrapper Id should match the database record Id.');
        System.assertEquals(repoWrapper.name, repoRecords[0].Name,
                'The repoWrapper name should match the database record name.');
        System.assertEquals(repoWrapper.repositoryUrl, repoRecords[0].Repository_URL__c,
                'The repoWrapper repositoryUrl should match the database record repositoryUrl.');
        System.assertEquals(repoWrapper.host, repoRecords[0].Host__c,
                'The repoWrapper host should match the database record host.');
        System.assertEquals(repoWrapper.orgName, repoRecords[0].Organization_Name__c, 
                'The repoWrapper host organization name should match the database record host organization name.');
        System.assertEquals(repoWrapper.metadataPath, repoRecords[0].SFDC_Metadata_Path__c,
                'The repoWrapper host metadata path should match the database record host organization name.');
    }

    private static testMethod void upsertRepository_createRepositoryWithEmptyRepoName() {
        Test.startTest();

            try {
                VCRepository repoWrapper = VCServices.upsertRepository(
                        '', '', 'https://www.git-bit-repo.org', 'GitBitBucket', 'ForTesting', '');
                System.assert(false,
                        'Should not succeed because an exception should have been thrown.');
            } catch (Exception e) {
                System.assert(e instanceof ALMException,
                        'Should throw an exception because the name is an empty string.');
            }

        Test.stopTest();
    }

    private static testMethod void upsertRepository_updateRepository() {
        setupRepositories();
        VCRepository repoWrapper;

        List<Id> repoIds = new List<Id>();
        repoIds.addAll(vcRepositories.keySet());
        Id repoId = repoIds[0];
        String name = 'git-bit-repo';
        String repoUrl = 'https://www.git-bit-repo.org';
        String host = 'GitHub';
        String orgName = 'ForTesting';
        String metadataPath = 'some/path';

        Test.startTest();

            try {
                repoWrapper = VCServices.upsertRepository(
                        repoId, name, repoUrl, host, orgName, metadataPath);
            } catch (Exception e) {
                System.assert(false,
                        'Should not have thrown an exception because the id, name, repoUrl, host, and orgName are valid Strings.');
            }

        Test.stopTest();

        List<VC_Repository__c> updatedRepos = [SELECT Id, Name, Repository_URL__c, Host__c,
                                                    Organization_Name__c, SFDC_Metadata_Path__c, Source_Format__c
                                                FROM VC_Repository__c
                                                WHERE Id=:repoId];

        System.assert(updatedRepos.size() != 0,
                'There should be a record in the database with the specific Id.');

        System.assertEquals(updatedRepos[0].Id, repoWrapper.id,
                'The repoWrapper Id should match the record Id.');
        System.assertEquals(updatedRepos[0].Name, repoWrapper.name,
                'The repoWrapper name should match the record name.');
        System.assertEquals(updatedRepos[0].Repository_URL__c, repoWrapper.repositoryUrl,
                'The repoWrapper repositoryUrl should match the record repositoryUrl.');
        System.assertEquals(updatedRepos[0].Host__c, repoWrapper.host,
                'The repoWrapper host should match the record host.');
        System.assertEquals(updatedRepos[0].Organization_Name__c, repoWrapper.orgName,
                'The repoWrapper host organization name should match the record host organization name.');
        System.assertEquals(updatedRepos[0].SFDC_Metadata_Path__c, repoWrapper.metadataPath,
                'The repoWrapper host metadata path should match the database record host organization name.');
    }

    private static testMethod void upsertRepository_updateRepositoryWithNoRecord() {
        setupRepositories();
        String badId = '12345789';
        String exceptionMessage = 'Invalid id: ' + badId;

        Test.startTest();

            try {
                VCRepository repoWrapper = VCServices.upsertRepository(
                        badId, 'git-bit-repo', 'https://www.git-bit-repo.org', 'GitHub', 'ForTesting', '');
                System.assert(false,
                        'Should not have succeeded because there are no records with that Id.');
            } catch (Exception e) {
                System.assertEquals(exceptionMessage, e.getMessage(),
                        'Should have thrown an exception because the id is empty.');
            }

        Test.stopTest();
    }

    private static testMethod void loadVcValidationsForMultipleRepos() {
        DateTime nowTime = DateTime.now();
        System.runAs(TestingUtils.ADMIN_USER){
            setupRepositories();
        }
        UnitTest.addData(vcRepositories.values()).tag('All VC Repos');
        UnitTest.get('All VC Repos')
            .divide(2)
                .part('Successful Val Attempt Repo')
                .part('Unsuccessful Val Attempt Repo');
        Map<Id, VC_Repository_Validation__c> expectedValidationsMap = new Map<Id, VC_Repository_Validation__c>();

        for (VC_Repository__c testRepo : (List<VC_Repository__c>)UnitTest.get('All VC Repos').getList()) {
            Boolean doInsert = false;
            VC_Repository_Validation__c testValidation = TestingUtils.createVcRepositoryValidation(testRepo, doInsert);

            if(UnitTest.analyze('Successful Val Attempt Repo').hasId(testRepo.Id)){
                testValidation.SuccessfulValidation__c = true;
            }else{
                testValidation.SuccessfulValidation__c = false;
                testValidation.ValidationError__c = 'validation error occurred';
            }

            testValidation.ValidationDate__c = nowTime;
            expectedValidationsMap.put(testRepo.Id, testValidation);
        }
        System.runAs(TestingUtils.ADMIN_USER){
            insert expectedValidationsMap.values();
        }
        List<VCRepository> actualReposWithValidations = new List<VCRepository>();

        Test.startTest();
            System.runAs(TestingUtils.ADMIN_USER){
                actualReposWithValidations = VCServices.loadVCReposWithValidationsForUser();
            }
        Test.stopTest();
        System.assertEquals(2, actualReposWithValidations.size(), 'The correct number of repos should be found');
        Map<Id, VCRepository> actualRepoIdToRepo = new Map<Id, VCRepository>();

        for (VCRepository repo : actualReposWithValidations) {
            actualRepoIdToRepo.put(repo.id, repo);
        }


        for(Id repoId : expectedValidationsMap.keySet() ){
            VC_Repository_Validation__c expectedValidation = expectedValidationsMap.get(repoId);
            System.assert(actualRepoIdToRepo.containsKey(repoId), 'The correct repos should be returned');
            System.assertNotEquals(null, actualRepoIdToRepo.get(repoId).validation, 'A validation record should exist for this repo');
            VCRepository.Validation actualValidation = actualRepoIdToRepo.get(repoId).validation;

            System.assertEquals(expectedValidation.ValidationDate__c, actualValidation.validationDate );
            System.assertEquals(expectedValidation.SuccessfulValidation__c, actualValidation.isSuccessful );
            System.assertEquals(expectedValidation.ValidationError__c, actualValidation.error );
            System.assertEquals(expectedValidation.VC_Repository__c, repoId );
        }
    }

    private static testMethod void upsertRepositoryWithAlmJob() {
        UnitTest.addData(buildRepositories()).tag('All VC Repos');
        
        VC_Repository__c expectedRepo = (VC_Repository__c) UnitTest.get('All VC Repos').getList()[0];
        ALM_Job__c expectedAlmJob = TestingUtils.buildVCRepoSyncJob(null, true);
        VCRepository testVCRepoModel = new VCRepository(expectedRepo, expectedAlmJob);
        
        Test.startTest();
            Boolean destroyJob = false;
            VCRepository actualRepo = VCServices.upsertRepositoryWithAlmJob(JSON.serialize(testVCRepoModel), destroyJob);
        Test.stopTest();
        
        assertVCRepo(actualRepo, expectedRepo);
        System.assertNotEquals( null, actualRepo.job, 'The alm Job of the repo should be set');
        ALM_Job__c actualJob = actualRepo.job.getJob();
        assertVCRepoALMJob(actualJob, expectedAlmJob);
    }

    private static testMethod void upsertRepositoryWithAlmJob_existing_repo() {
        UnitTest.addData(buildRepositories()).tag('All VC Repos');
        
        VC_Repository__c expectedRepo = (VC_Repository__c) UnitTest.get('All VC Repos').getList()[0];
        ALM_Job__c expectedAlmJob = TestingUtils.createVCRepoSyncJob(expectedRepo.Id);
        ALM_Application_Result__c expectedResult = TestingUtils.buildAlmApplicationResult(DateTime.Now(), 
                                                                                          DateTime.Now().addDays(2), 
                                                                                          'SUCCESS', null, null, 
                                                                                          ALMJobServices.ToolType.VC_REPO_SYNC );
        expectedResult.ALM_Job__c = expectedAlmJob.Id;
        insert expectedResult;
                                                                                         
        VCRepository testVCRepoModel = new VCRepository(expectedRepo, expectedAlmJob);
        testVCRepoModel.job.applicationResults = new List<ALMApplicationResultModel> {new ALMApplicationResultModel(expectedResult)};
        
        Test.startTest();
            Boolean destroyJob = false;
            VCRepository actualRepo = VCServices.upsertRepositoryWithAlmJob(JSON.serialize(testVCRepoModel), destroyJob);
        Test.stopTest();
        
        assertVCRepoWithJobAndResult(actualRepo, expectedRepo, expectedAlmJob, expectedResult );
    }

    private static testMethod void upsertRepositoryWithAlmJob_deleteJob() {
        setupRepositories();
        UnitTest.addData(vcRepositories.values()).tag('All VC Repos');
        
        VC_Repository__c expectedRepo = (VC_Repository__c) UnitTest.get('All VC Repos').getList()[0];
        ALM_Job__c expectedAlmJob = TestingUtils.createVCRepoSyncJob(expectedRepo.Id);
        
        //Change the repo name
        expectedRepo.Name = 'Change Me';
        VCRepository testVCRepoModel = new VCRepository(expectedRepo, expectedAlmJob);
        
        Test.startTest();
            Boolean destroyJob = true;
            VCRepository actualRepo = VCServices.upsertRepositoryWithAlmJob(JSON.serialize(testVCRepoModel), destroyJob);    
        Test.stopTest();
        
        assertVCRepo(actualRepo, expectedRepo);
        System.assertEquals( null, actualRepo.job, 'The alm Job of the repo should not be set');
        List<ALM_Job__c> allJobs = [Select Id from ALM_Job__c limit 1];
        System.assertEquals(0, allJobs.size(), 'No Jobs should exist in the database');
    }

    private static testMethod void getVCRepository() {
        setupRepositories();
        UnitTest.addData(vcRepositories.values()).tag('All VC Repos');
        UnitTest.get('All VC Repos')
            .divide(2)
                .part('Expected Repo')
                .part('UnExpected Repo');
                
        
        VC_Repository__c expectedRepo = (VC_Repository__c) UnitTest.get('Expected Repo').getList()[0];
        ALM_Job__c expectedAlmJob;
        ALM_Application_Result__c expectedAlmJobResult;
        List<ALM_Application_Result__c> appResultsToInsert = new List<ALM_Application_Result__c>();
        
        for( VC_Repository__c repo : vcRepositories.values()) {
            ALM_Job__c childJob = TestingUtils.createVCRepoSyncJob(repo.Id);
            ALM_Application_Result__c childResult = TestingUtils.buildAlmApplicationResult(DateTime.Now(), 
                                                                                            DateTime.Now().addDays(2), 
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
            VCRepository actualRepo = VCServices.getVCRepository( expectedRepo.id );
        Test.stopTest();
        
        assertVCRepoWithJobAndResult(actualRepo, expectedRepo, expectedAlmJob, expectedAlmJobResult );
    }
    @TestVisible
    private static void assertVCRepoWithJobAndResult(VCRepository actualRepo, VC_Repository__c expectedRepo, 
                                                     ALM_Job__c expectedAlmJob, ALM_Application_Result__c expectedAlmJobResult ) {
        assertVCRepo(actualRepo, expectedRepo);
        System.assertNotEquals( null, actualRepo.job, 'The alm Job of the repo should be set');
        ALM_Job__c actualJob = actualRepo.job.getJob();
        assertVCRepoALMJob(actualJob, expectedAlmJob);
                
        System.assertNotEquals( null, actualRepo.job.applicationResults, 'The alm Job results of the repo should be set');
        List<ALMApplicationResultModel> almResultModels = actualRepo.job.applicationResults;
        System.assertEquals(1, almResultModels.size(), 'One alm result should be found');
        System.assertEquals(expectedAlmJobResult.id, almResultModels[0].id, 'The correct alm application result should be found');
    }
    
    @TestVisible
    private static void assertVCRepo(VCRepository actualRepo, VC_Repository__c expectedRepo) {
        VC_Repository__c actualRepoRecord = actualRepo.getRepo(); 
        if(expectedRepo.id != null) {
            System.assertEquals(expectedRepo.id, actualRepoRecord.id, 'The correct record Id should be returned');
        }
        System.assertEquals(expectedRepo.Name, actualRepoRecord.Name, 'The correct record Name should be returned');
        System.assertEquals(expectedRepo.Repository_URL__c, actualRepoRecord.Repository_URL__c, 'The correct record url should be returned');
        System.assertEquals(expectedRepo.Host__c, actualRepoRecord.Host__c, 'The correct record host should be returned');
        System.assertEquals(expectedRepo.Organization_Name__c, actualRepoRecord.Organization_Name__c, 'The correct record org should be returned');
        System.assertEquals(expectedRepo.Sync_Revisions_From__c, actualRepoRecord.Sync_Revisions_From__c, 'The correct record sync date should be returned');
    }
    
    @TestVisible
    private static void assertVCRepoALMJob(ALM_Job__c actualJob, ALM_Job__c expectedAlmJob) {
        if(expectedAlmJob.id != null) {
            System.assertEquals(expectedAlmJob.id, actualJob.id, 'The correct record Id on the job should be returned');
        }
        System.assertEquals(expectedAlmJob.Tool__c, actualJob.Tool__c, 'The correct Tool on the job should be returned');
        System.assertEquals(expectedAlmJob.Status__c, actualJob.Status__c, 'The correct Status on the job should be returned');
        System.assertEquals(expectedAlmJob.Mail_To__c, actualJob.Mail_To__c, 'The correct Mailto on the job should be returned');
        System.assertEquals(expectedAlmJob.Scheduled_Start_Time__c.Time(), actualJob.Scheduled_Start_Time__c.Time(), 'The correct startTime on the job should be returned');
        System.assertEquals(expectedAlmJob.Scheduled_End_Time__c.Time(), actualJob.Scheduled_End_Time__c.Time(), 'The correct endTime on the job should be returned');
        System.assertEquals(expectedAlmJob.Last_Queue_Time__c, actualJob.Last_Queue_Time__c, 'The correct lastQueueTime on the job should be returned');
        System.assertEquals(expectedAlmJob.Interval__c, actualJob.Interval__c, 'The correct interval on the job should be returned');
        System.assertEquals(expectedAlmJob.Scheduled_On_Monday__c, actualJob.Scheduled_On_Monday__c, 'The correct Monday schedule on the job should be returned');
        System.assertEquals(expectedAlmJob.Scheduled_On_Tuesday__c, actualJob.Scheduled_On_Tuesday__c, 'The correct Tuesday schedule on the job should be returned');
        System.assertEquals(expectedAlmJob.Scheduled_On_Wednesday__c, actualJob.Scheduled_On_Wednesday__c, 'The correct Wednesday schedule on the job should be returned');
        System.assertEquals(expectedAlmJob.Scheduled_On_Thursday__c, actualJob.Scheduled_On_Thursday__c, 'The correct Thursday schedule on the job should be returned');
        System.assertEquals(expectedAlmJob.Scheduled_On_Friday__c, actualJob.Scheduled_On_Friday__c, 'The correct Friday schedule on the job should be returned');
        System.assertEquals(expectedAlmJob.Scheduled_On_Saturday__c, actualJob.Scheduled_On_Saturday__c, 'The correct Saturday schedule on the job should be returned');
        System.assertEquals(expectedAlmJob.Scheduled_On_Sunday__c, actualJob.Scheduled_On_Sunday__c, 'The correct Sunday schedule on the job should be returned');
            
    }

    private static testMethod void validateRepoNameForDuplicate() {

        setupRepositories();

        List<VC_Repository__c> newRepos = new List<VC_Repository__c>();
        //first addition here is a duplicate and second is not
        newRepos.add(new VC_Repository__c(
                Name='git-rEpo', Repository_URL__c='coolthing@github.com'));
        newRepos.add(new VC_Repository__c(
                Name='git-RePO', Repository_URL__c='coolthing@github.com'));
        newRepos.add(new VC_Repository__c(
                Name='git-RePOnewName', Repository_URL__c='coolthing@github.com'));

        Test.startTest();
            List<VC_Repository__c> duplicateRepos = VCServices.validateRepoNamesForDuplicate(newRepos);
        Test.stopTest();

        //the method validateRepoNamesForDuplicates breaks the loop after it finds one
        System.assertEquals(2, duplicateRepos.size(), 'There should be two repos with duplicate names.');
    }

    private static testMethod void testVCRepoTrigger_insert() {
        List<VC_Repository__c> newRepos = new List<VC_Repository__c>();

        newRepos.add(new VC_Repository__c(
                Name='giT-rePo', Repository_URL__c='coolthing@github.com'));
        newRepos.add(new VC_Repository__c(
                Name='GiT-RepO', Repository_URL__c='coolthing@github.com'));
        try{
            insert newRepos;
            System.assert(false, 'The trigger should throw an exception for duplicate repo.');
        }
        catch (Exception e){
            System.assert(e.getMessage().contains(System.Label.Duplicate_Repo_Name_Error));
        }
    }

    private static testMethod void testVCRepoTrigger_insert_noDuplicate() {
        List<VC_Repository__c> newRepos = new List<VC_Repository__c>();

        newRepos.add(new VC_Repository__c(
                Name='giT-rePo', Repository_URL__c='coolthing@github.com'));
        newRepos.add(new VC_Repository__c(
                Name='GiT-RepO2', Repository_URL__c='coolthing@github.com'));
        try {
            insert newRepos;
            Map<Id, VC_Repository__c> insertedRepos = new Map<Id, VC_Repository__c>([SELECT Id from VC_Repository__c]);
            System.assert(insertedRepos.keySet().contains(newRepos[0].Id), 'The database should contain the repos that were inserted.');
            System.assert(insertedRepos.keySet().contains(newRepos[1].Id), 'The database should contain the repos that were inserted.');
            System.assertEquals(newRepos.size(), insertedRepos.keySet().size(), 'The number of repos in the database should be correct.');

        }
        catch (Exception e) {
            System.assert(false, 'Insert should work without exception.');
        }
    }

    private static testMethod void testVCRepoTrigger_update_name() {

        setupRepositories();

        for (VC_Repository__c repo: vcRepositories.values()) {
            if(repo.Name.equals(GIT_REPO_NAME)){
                repo.Name = BITBUCKET_REPO_NAME;
                try{
                    update repo;
                    System.assert(false, 'The trigger should throw an exception for duplicate repo.');

                }
                catch (Exception e){
                    System.assert(e.getMessage().contains(System.Label.Duplicate_Repo_Name_Error));
                }
            }
        }
    }

    private static testMethod void testVCRepoTrigger_update_name_noDuplicate() {
        final String REPO_2_URL = 'repo2@github.com';
        VC_Repository__c repo1 = new VC_Repository__c( Name='git-repo1', Repository_URL__c='repo1@github.com' );
        VC_Repository__c repo2 = new VC_Repository__c( Name='git-repo2', Repository_URL__c=REPO_2_URL );
        
        try{
            insert repo1;
            insert repo2;

            final String NEW_NAME = 'newName';
            repo2.Name = NEW_NAME;
            update repo2;

            VC_Repository__c secondRepo = [SELECT Name from VC_Repository__c where Repository_URL__c = :REPO_2_URL];
            System.assertEquals(NEW_NAME, secondRepo.Name, 'The repo name should be properly updated.');
        }
        catch (Exception e){
            System.assert(false, 'The update should work without throwing exception.');
        }
    }

    private static testMethod void testVCRepoTrigger_update_url() {

        setupRepositories();
        VC_Repository__c repo = vcRepositories.values()[0];
        repo.Repository_URL__c = 'newurlthatshouldntbeaproblem@noproblem.com';

        try{
            update repo;
        }
        catch (Exception e){
            System.assert(false, 'Changing a repo url should not cause an error with the trigger.');
        }
    }

}
