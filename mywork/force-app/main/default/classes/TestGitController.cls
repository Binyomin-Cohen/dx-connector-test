@isTest
private class TestGitController {
    private static final String TEST_BRANCH_NAME = 'feature-branch';
    private static final String TEST_REPOSITORY_URL = 'https://www.example.com/test-repository';
    private static final String TEST_PUBLIC_KEY = 'Test Public Key';
    private static final String TEST_PRIVATE_KEY = 'Test Private Key';
    private static final String TEST_PASSPHRASE = 'Test Passphrase';

    private static final String TEST_LIST_FAILURE_REASON = 'Test Failure Reason';

    private static testMethod void retrieveBranches() {
        String successGitListResponse = MockVCAPI.setupGitListSuccessResponse( new List<String> { TEST_BRANCH_NAME } );
        Test.setMock(HttpCalloutMock.class, new MockVCAPI(successGitListResponse));

        Blob testManagementKey = Crypto.generateAesKey(SSHServices.MANAGEMENT_ENCRYPTION_KEY_BIT_WIDTH);
        TestingUtils.createSSHPrivateSettings(testManagementKey);
        TestingUtils.createSSHUserKeypair(TEST_PUBLIC_KEY, TEST_PRIVATE_KEY, TEST_PASSPHRASE, testManagementKey,  UserInfo.getUserId());

        VC_Repository__c vcRepository = new VC_Repository__c(
            Repository_URL__c = TEST_REPOSITORY_URL
        );
        insert vcRepository;

        Test.startTest();

            List<String> branches = GitController.retrieveBranches(vcRepository.Id);

        Test.stopTest();

        System.assertNotEquals(null, branches, 'The branches result should be returned.');
        System.assertEquals(1, branches.size(), 'The branches result should be returned.');
        System.assertEquals(TEST_BRANCH_NAME, branches[0], 'The branches result should be returned.');
    }

    private static testMethod void retrieveBranches_errorResult() {
        String failureResponse = MockVCAPI.setupGitListFailureResponse(TEST_LIST_FAILURE_REASON);
        Test.setMock(HttpCalloutMock.class, new MockVCAPI(failureResponse));

        Blob testManagementKey = Crypto.generateAesKey(SSHServices.MANAGEMENT_ENCRYPTION_KEY_BIT_WIDTH);
        TestingUtils.createSSHPrivateSettings(testManagementKey);
        TestingUtils.createSSHUserKeypair(TEST_PUBLIC_KEY, TEST_PRIVATE_KEY, TEST_PASSPHRASE, testManagementKey,  UserInfo.getUserId());

        VC_Repository__c vcRepository = new VC_Repository__c(
            Repository_URL__c = TEST_REPOSITORY_URL
        );
        insert vcRepository;

        Test.startTest();

            try {
                GitController.retrieveBranches(vcRepository.Id);
                System.assert(false, 'An exception should be thrown when the request is not succesful');
            } catch (Exception ae) {
                System.assert(ae instanceof AuraHandledException, 'An AuraHandledException be returned as the message.');
            }
        Test.stopTest();
    }

    private static testMethod void retrieveRepos() {

        final String REPO_NAME = 'test repo';
        VC_Repository__c vcRepository = new VC_Repository__c(
            Name = REPO_NAME,
            Repository_URL__c = TEST_REPOSITORY_URL
        );
        insert vcRepository;

        Test.startTest();
            List<GitController.RepositoryResult> results = GitController.retrieveRepos();
        Test.stopTest();

        System.assertEquals(1, results.size(), 'The repository results should be populated');
        System.assertEquals(REPO_NAME, results[0].name, 'The repository name should be populated');
        System.assertEquals(TEST_REPOSITORY_URL, results[0].repoURL, 'The repository URL should be populated');
        System.assertEquals(vcRepository.Id, results[0].id, 'The repository Id should be populated');
    }

    private static testMethod void retrieveRepos_noResults() {
        Test.startTest();
            List<GitController.RepositoryResult> results = GitController.retrieveRepos();
        Test.stopTest();

        System.assertEquals(0, results.size(), 'The repository results should be empty when no reposisories exist');
    }

    private static testMethod void saveCommitRequest_vcCommitRecordIsCreated() {
        VC_Repository__c repo = new VC_Repository__c(Repository_URL__c = 'url');
        insert repo;

        String backlogItemId = TestingUtils.createBacklogItem().Id;
        List<String> backlogComponentIdsList = new List<String>{'Id_1', 'Id_2'};
        String backlogComponentIds = String.join(backlogComponentIdsList, ',');
        String repositoryId = repo.Id;
        String branchName = 'branch name';
        String commitMessage = 'commit message';
        Instances__c instance = TestingUtils.createInstance('test instance');

        GitController.CommitRequest vcCommit =
            new GitController.CommitRequest(backlogItemId, backlogComponentIdsList, repositoryId,
                                            branchName, commitMessage, instance.Id);

        String requestJSON = JSON.serialize(vcCommit);

        Test.startTest();
            String vcCommitId = GitController.saveCommitRequest(requestJSON);
        Test.stopTest();

        VC_Commit__c requeriedVcCommit =[SELECT Backlog_Item__c, Branch_Name__c, Commit_Message__c, VC_Repository__c,
                                                  Backlog_Components__c, Response_Message__c, Source_Instance__c, Status__c
                                           FROM VC_Commit__c
                                           WHERE Id=:vcCommitId];

        System.assert(String.isNotEmpty(requeriedVcCommit.Id),
                      'The saveCommitRequest should return a VC_Commit__c Id');
        System.assertEquals(backlogItemId, requeriedVcCommit.Backlog_Item__c,
                            'The backlogItemId should be correct');
        System.assertEquals(backlogComponentIds , requeriedVcCommit.Backlog_Components__c,
                            'The backlogComponentIds should be correct');
        System.assertEquals(repositoryId, requeriedVcCommit.VC_Repository__c,
                            'The repositoryId should be correct');
        System.assertEquals(branchName, requeriedVcCommit.Branch_Name__c,
                            'The branchName should be correct');
        System.assertEquals(commitMessage, requeriedVcCommit.Commit_Message__c,
                            'The commitMessage should be correct');
        System.assertEquals(instance.Id, requeriedVcCommit.Source_Instance__c,
                            'The instance should be correct');
    }

    private static testMethod void makeCommitRequest_successWithValidVCCommit() {
        Test.setMock(HttpCalloutMock.class, new MockWebAssemblerAPI(MockWebAssemblerAPI.GIT_COMMIT_SUCCESS_ACTION));
        VC_Commit__c vcCommit;
        System.runAs(TestingUtils.ADMIN_USER) {
            vcCommit = TestingUtils.setupVCCommit();
        }

        Test.startTest();

            PageMessage result;
            System.runAs(TestingUtils.ADMIN_USER) {
                result = GitController.makeCommitRequest(vcCommit.Id);
            }

        Test.stopTest();

        System.assertEquals(ApexPages.Severity.CONFIRM.name().toLowerCase(), result.messageType,
                            'The Message Type should be a confirmation');

        System.assertEquals(GitController.SUCCESS_COMMIT_MESSAGE, result.message,
                            'The Success Message should be returned');

    }

    private static testMethod void makeCommitRequest_invalidCommitThrowsException() {
        VC_Commit__c vcCommit;
        System.runAs(TestingUtils.ADMIN_USER) {
            vcCommit = TestingUtils.setupVCCommit();
        }
        // Mess up the vcCommit
        vcCommit.Source_Instance__c = null;
        update vcCommit;

        Test.startTest();

            System.runAs(TestingUtils.ADMIN_USER) {

                try {
                    GitController.makeCommitRequest(vcCommit.Id);
                    System.assert(false, 'An Exception Should have been thrown from the commit request');
                } catch (Exception ae) {
                    // TODO: assert on exception messages.
                }
            }

        Test.stopTest();


    }

    private static final String testBacklogItemId = 'Test Backlog ID';
    private static final String testOtherBacklogItemId = 'Test Other Backlog ID';
    private static final String testKeyString = 'String';
    private static final String testKeyInteger = 'Integer';
    private static final String testKeyMap = 'Map';
    private static final String testValueKeyFoo = 'Foo';
    private static final String testValueKeyBar = 'Bar';

    private static Map<String, Object> setup_stateMap() {
        return new Map<String, Object>{
            testKeyString => 'Test String',
            testKeyInteger => 3,
            testKeyMap => new Map<String, Object>{
                testValueKeyFoo => 0,
                testValueKeyBar => '1'
            }
        };
    }

    private static void assertProperPageState(Map<String, Object> expectedPageStateMap, Map<String, Object> actualPageStateMap) {
        System.assertNotEquals(null, expectedPageStateMap, 'The expected page state map should not be null.');
        System.assertNotEquals(null, actualPageStateMap, 'The actual page state map should not be null.');

        System.assert(actualPageStateMap.containsKey(testKeyString), 'The state record should contain the proper key.');
        System.assertEquals(expectedPageStateMap.get(testKeyString), actualPageStateMap.get(testKeyString), 'The state record should contain the proper value.');
        System.assert(actualPageStateMap.containsKey(testKeyInteger), 'The state record should contain the proper key.');
        System.assertEquals(expectedPageStateMap.get(testKeyInteger), actualPageStateMap.get(testKeyInteger), 'The state record should contain the proper value.');
        System.assert(actualPageStateMap.containsKey(testKeyMap), 'The state record should contain the proper key.');

        Map<String, Object> expectedPageStateMapValueMap = (Map<String, Object>)expectedPageStateMap.get(testKeyMap);
        Map<String, Object> actualPageStateMapValueMap = (Map<String, Object>)actualPageStateMap.get(testKeyMap);

        System.assertEquals(expectedPageStateMapValueMap.get(testValueKeyFoo), actualPageStateMapValueMap.get(testValueKeyFoo), 'The state record should contain the proper value.');
        System.assertEquals(expectedPageStateMapValueMap.get(testValueKeyBar), actualPageStateMapValueMap.get(testValueKeyBar), 'The state record should contain the proper value.');
    }

    private static testMethod void savePageState_nullState() {
        Test.startTest();

            try {
                GitController.savePageState(testBacklogItemId, null);
            } catch (Exception e) {
                System.assert(false, 'No exceptions should be thrown.');
            }

        Test.stopTest();
    }

    private static testMethod void savePageState_singleBacklogItem_valid() {
        Map<String, Object> testPageStateMap = setup_stateMap();

        Test.startTest();

            GitController.savePageState(testBacklogItemId, testPageStateMap);

        Test.stopTest();

        List<State__c> actualState = [
            SELECT State_Chunk_1__c
            FROM State__c
            WHERE Token__c = :(new PageState(GitController.constructPageStateToken(testBacklogItemId)).getStateToken())
        ];
        System.assertEquals(1, actualState.size(), 'A single matching state record should be saved.');
        Map<String, Object> actualPageStateMap = (Map<String, Object>)JSON.deserializeUntyped(actualState[0].State_Chunk_1__c);
        assertProperPageState(testPageStateMap, actualPageStateMap);
    }

    private static testMethod void savePageState_singleBacklogItem_overwritesOldState() {
        GitController.savePageState(testBacklogItemId, new Map<String, Object>());

        List<State__c> actualState = [
            SELECT State_Chunk_1__c
            FROM State__c
            WHERE Token__c = :(new PageState(GitController.constructPageStateToken(testBacklogItemId)).getStateToken())
        ];
        Map<String, Object> actualPageStateMap = (Map<String, Object>)JSON.deserializeUntyped(actualState[0].State_Chunk_1__c);
        System.assertNotEquals(null, actualPageStateMap, 'The existing state should be stored properly.');


        Map<String, Object> testPageStateMap = setup_stateMap();

        Test.startTest();

            GitController.savePageState(testBacklogItemId, testPageStateMap);

        Test.stopTest();

        actualState = [
            SELECT State_Chunk_1__c
            FROM State__c
            WHERE Token__c = :(new PageState(GitController.constructPageStateToken(testBacklogItemId)).getStateToken())
        ];
        System.assertEquals(1, actualState.size(), 'A single matching state record should be saved.');
        actualPageStateMap = (Map<String, Object>)JSON.deserializeUntyped(actualState[0].State_Chunk_1__c);
        assertProperPageState(testPageStateMap, actualPageStateMap);
    }

    private static testMethod void savePageState_multipleBacklogItems_doesNotOverwriteStateForOtherBacklogItem() {
        GitController.savePageState(testOtherBacklogItemId, new Map<String, Object>());

        List<State__c> actualState = [
            SELECT State_Chunk_1__c
            FROM State__c
            WHERE Token__c = :(new PageState(GitController.constructPageStateToken(testOtherBacklogItemId)).getStateToken())
        ];
        Map<String, Object> actualPageStateMap = (Map<String, Object>)JSON.deserializeUntyped(actualState[0].State_Chunk_1__c);
        System.assertNotEquals(null, actualPageStateMap, 'The existing state should be stored properly.');


        Map<String, Object> testPageStateMap = setup_stateMap();

        Test.startTest();

            GitController.savePageState(testBacklogItemId, testPageStateMap);

        Test.stopTest();

        Integer stateCount = [
            SELECT Count()
            FROM State__c
            WHERE
                Token__c = :(new PageState(GitController.constructPageStateToken(testBacklogItemId)).getStateToken()) OR
                Token__c = :(new PageState(GitController.constructPageStateToken(testOtherBacklogItemId)).getStateToken())
        ];

        System.assertEquals(2, stateCount, 'Two parallel state records should be saved.');

        actualState = [
            SELECT State_Chunk_1__c
            FROM State__c
            WHERE Token__c = 
                :(new PageState(GitController.constructPageStateToken(testOtherBacklogItemId)).getStateToken())
        ];
        actualPageStateMap = (Map<String, Object>)JSON.deserializeUntyped(actualState[0].State_Chunk_1__c);
        System.assertNotEquals(null, actualPageStateMap, 'The existing state should be stored properly.');

        actualState = [
            SELECT State_Chunk_1__c
            FROM State__c
            WHERE Token__c = 
                :(new PageState(GitController.constructPageStateToken(testBacklogItemId)).getStateToken())
        ];

        System.assertEquals(1, actualState.size(), 'A single matching state record should be saved.');
        actualPageStateMap = (Map<String, Object>)JSON.deserializeUntyped(actualState[0].State_Chunk_1__c);
        assertProperPageState(testPageStateMap, actualPageStateMap);
    }

    private static testMethod void loadPageState_noState() {
        Test.startTest();

            Map<String, Object> actualPageStateMap;
            try {
                actualPageStateMap = GitController.loadPageState(testBacklogItemId);
            } catch (Exception e) {
                System.assert(false, 'No exceptions should be thrown.');
            }

        Test.stopTest();

        System.assertEquals(null, actualPageStateMap, 'No state should exist.');
    }

    private static testMethod void loadPageState_singleBacklogItem_valid() {
        Map<String, Object> testPageStateMap = setup_stateMap();

        State.store(new PageState(GitController.constructPageStateToken(testBacklogItemId), testPageStateMap));

        Test.startTest();

            Map<String, Object> actualPageStateMap = GitController.loadPageState(testBacklogItemId);

        Test.stopTest();

        assertProperPageState(testPageStateMap, actualPageStateMap);
    }

    private static testMethod void loadPageState_multipleBacklogItems_valid() {
        Map<String, Object> testPageStateMap = setup_stateMap();

        State.store(new PageState(GitController.constructPageStateToken(testBacklogItemId), testPageStateMap));
        State.store(new PageState(GitController.constructPageStateToken(testOtherBacklogItemId), new Map<String, Object>()));

        Test.startTest();

            Map<String, Object> actualPageStateMap = GitController.loadPageState(testBacklogItemId);

        Test.stopTest();

        assertProperPageState(testPageStateMap, actualPageStateMap);
    }

    private static testMethod void expirePageState_singleBacklogItem_noStateExists() {
        Test.startTest();

            try {
                GitController.expirePageState(testBacklogItemId);
            } catch (Exception e) {
                System.assert(false, 'No exceptions should be thrown.');
            }

        Test.stopTest();

        Integer stateCount = [
            SELECT Count()
            FROM State__c
            WHERE Token__c = :(new PageState(GitController.constructPageStateToken(testBacklogItemId)).getStateToken())
        ];

        System.assertEquals(0, stateCount, 'No state records should exist.');
    }

    private static testMethod void expirePageState_singleBacklogItem_stateExists() {
        State.store(new PageState(GitController.constructPageStateToken(testBacklogItemId), setup_stateMap()));

        Integer stateCount = [
            SELECT Count()
            FROM State__c
            WHERE Token__c = :(new PageState(GitController.constructPageStateToken(testBacklogItemId)).getStateToken())
        ];

        System.assertEquals(1, stateCount, 'A single state record should exist.');

        Test.startTest();

            GitController.expirePageState(testBacklogItemId);

        Test.stopTest();

        stateCount = [
            SELECT Count()
            FROM State__c
            WHERE Token__c = :(new PageState(GitController.constructPageStateToken(testBacklogItemId)).getStateToken())
        ];

        System.assertEquals(0, stateCount, 'No state records should exist.');
    }

    private static testMethod void expirePageState_multipleBacklogItems_stateExists() {
        State.store(new PageState(GitController.constructPageStateToken(testBacklogItemId), setup_stateMap()));
        State.store(new PageState(GitController.constructPageStateToken(testOtherBacklogItemId), setup_stateMap()));

        Integer stateCount = [
            SELECT Count()
            FROM State__c
            WHERE
                Token__c = :(new PageState(GitController.constructPageStateToken(testBacklogItemId)).getStateToken()) OR
                Token__c = :(new PageState(GitController.constructPageStateToken(testOtherBacklogItemId)).getStateToken())
        ];

        System.assertEquals(2, stateCount, 'Two state records should exist.');

        Test.startTest();

            GitController.expirePageState(testOtherBacklogItemId);

        Test.stopTest();

        stateCount = [
            SELECT Count()
            FROM State__c
            WHERE Token__c = :(new PageState(GitController.constructPageStateToken(testBacklogItemId)).getStateToken())
        ];

        System.assertEquals(1, stateCount, 'The proper single state record should exist.');

        stateCount = [
            SELECT Count()
            FROM State__c
            WHERE Token__c = :(new PageState(GitController.constructPageStateToken(testOtherBacklogItemId)).getStateToken())
        ];

        System.assertEquals(0, stateCount, 'The proper single state record should not exist.');
    }
}