@isTest
public class TestJenkinsServices {
    private static final String UNIQUE_JENKINS_NAME_PREFIX = 'TestJenkinsServices';
    private static final String TEST_ENDPOINT = 'http://www.example.com';
    private static final String TEST_USER_ID = 'TestUserID';
    private static final String TEST_USER_API_TOKEN = 'test_user_api_token';
    public static final String TEST_JOB_PATH = 'test/job/path';
    public static final String TEST_JOB_TOKEN = 'test_job_token';

    private static final String VALID_FIELD_NAME = SObjectServices.getFullyQualifiedName('Pre_Steps_Completed__c');

    private static Jenkins_Config__c jenkinsConfig;

    public static Release__c testRelease;
    private static Instances__c testInstance;
    private static Backlog__c testBacklogItem;

    public static void setupJenkinsConfig() {
        jenkinsConfig = new Jenkins_Config__c(
            Endpoint__c = TEST_ENDPOINT,
            User_ID__c = TEST_USER_ID,
            User_API_Token__c = TEST_USER_API_TOKEN
        );
        insert jenkinsConfig;
    }

    public static void setupReleaseWithBacklogItem() {
        testRelease = new Release__c(Name = 'Test Release Name');
        insert testRelease;

        testInstance = new Instances__c(Name = 'Test Instance Name');
        insert testInstance;

        testBacklogItem = new Backlog__c(Release__c = testRelease.Id);
        insert testBacklogItem;
    }

    public static Jenkins_Job__c createJenkinsJob(String path, String token) {

        Jenkins_Job__c jenkinsJob = TestingUtils.buildJenkinsJob(testInstance.Id, testRelease.Id);
        jenkinsJob.Path__c = path;
        jenkinsJob.Token__c = token;

        insert jenkinsJob;
        return jenkinsJob;
    }

    public static String setupExpectedPackageContent() {
        Component__c testProfileComponent =
            TestingUtils.createComponent('Test Profile Component Name', 'Profile', testInstance.Id);

        Backlog_Component__c testBacklogComponent =
            TestingUtils.createDocumentedBacklogComponent(testBacklogItem.Id, testInstance);
        Backlog_Component__c testProfileBacklogComponent =
            TestingUtils.createDocumentedProfile(testBacklogItem.Id, testProfileComponent, testInstance.Id);

        Backlog_Component__c actualBacklogComponent =
            [SELECT Component__r.Name FROM Backlog_Component__c WHERE Id = :testBacklogComponent.Id];
        Backlog_Component__c actualProfileBacklogComponent =
            [SELECT Component__r.Name FROM Backlog_Component__c WHERE Id = :testProfileBacklogComponent.Id];

        String expectedPackageContent =
            actualBacklogComponent.Component__r.Name + ',' + actualProfileBacklogComponent.Component__r.Name;
        return expectedPackageContent;
    }

    /**
    * @return a new Jenkins_Build__c with the name auto number populated
    */
    public static Jenkins_Build__c createJenkinsBuild(Id jobId) {
        Jenkins_Build__c build = new Jenkins_Build__c(Jenkins_Job__c=jobId);
        insert build;
        return [SELECT Id, Name, Jenkins_Job__c FROM Jenkins_Build__c WHERE Id = :build.Id][0];
    }

    private static testMethod void getExistingBuildRuleCriteria() {
        setupReleaseWithBacklogItem();
        Jenkins_Job__c job = TestingUtils.buildJenkinsJob(testInstance.Id, testRelease.Id);

        Build_Rule__c rule = new Build_Rule__c();
        rule.Boolean_Criteria__c = VALID_FIELD_NAME;
        insert rule;

        job.Build_Rule__c = rule.Id;
        insert job;

        job.Build_Rule__r = rule;

        Test.startTest();

            Set<String> criteria = JenkinsServices.getExistingBuildRuleCriteria(job);

        Test.stopTest();

        System.assertEquals(1, criteria.size(), 'The defined build rules should be returned');
        System.assertEquals(true, criteria.contains(VALID_FIELD_NAME), 'The defined build rules should be returned');
    }

    private static testMethod void getExistingBuildRuleCriteria_noRules() {
        setupReleaseWithBacklogItem();
        Jenkins_Job__c job = TestingUtils.buildJenkinsJob(testInstance.Id, testRelease.Id);

        Build_Rule__c rule = new Build_Rule__c();
        insert rule;

        job.Build_Rule__c = rule.Id;
        insert job;

        job.Build_Rule__r = rule;

        Test.startTest();

            Set<String> criteria = JenkinsServices.getExistingBuildRuleCriteria(job);

        Test.stopTest();

        System.assertEquals(true, criteria.isEmpty(), 'An empty set should be returned when there are no build rules defined');
    }

    private static testMethod void getBuildRuleCriteriaEvaluations_falseValues() {

        setupReleaseWithBacklogItem();
        Jenkins_Job__c job = TestingUtils.buildJenkinsJob(testInstance.Id, testRelease.Id);

        Build_Rule__c rule = new Build_Rule__c();
        rule.Boolean_Criteria__c = VALID_FIELD_NAME;
        insert rule;

        job.Build_Rule__c = rule.Id;
        insert job;

        job.Build_Rule__r = rule;

        Test.startTest();

            Map<String, Boolean> criteria = JenkinsServices.getBuildRuleCriteriaEvaluations(job);

        Test.stopTest();

        System.assertEquals(1, criteria.size(), 'The defined build rules should be returned');
        System.assertEquals(true, criteria.containsKey(VALID_FIELD_NAME), 'The defined build rules should be returned');
        System.assertEquals(false, criteria.get(VALID_FIELD_NAME), 'The build rule criteria should be evaluated');
    }

    private static testMethod void getBuildRuleCriteriaEvaluations_trueValues() {

        setupReleaseWithBacklogItem();
        Jenkins_Job__c job = TestingUtils.buildJenkinsJob(testInstance.Id, testRelease.Id);

        Build_Rule__c rule = new Build_Rule__c();
        rule.Boolean_Criteria__c = VALID_FIELD_NAME;
        insert rule;

        job.Build_Rule__c = rule.Id;
        insert job;

        job.Build_Rule__r = rule;

        CI_Instance__c instance = new CI_Instance__c(Id=job.CI_Instance__c);
        instance.put(VALID_FIELD_NAME, true);
        update instance;

        Test.startTest();

            Map<String, Boolean> criteria = JenkinsServices.getBuildRuleCriteriaEvaluations(job);

        Test.stopTest();

        System.assertEquals(1, criteria.size(), 'The defined build rules should be returned');
        System.assertEquals(true, criteria.containsKey(VALID_FIELD_NAME), 'The defined build rules should be returned');
        System.assertEquals(true, criteria.get(VALID_FIELD_NAME), 'The build rule criteria should be evaluated');
    }

    private static testMethod void createJenkinsBuild_ErrorWhenVCRepoButNoBranch() {
        Boolean createRepo = true;
        TestingUtils.JenkinsJobSetup setup = new TestingUtils.JenkinsJobSetup(createRepo, UNIQUE_JENKINS_NAME_PREFIX);

        Jenkins_Job__c job = setup.jenkinsJob;
        job.Source_Repository_Location__c = null;
        update job;

        Test.startTest();
            try {
                String buildId = JenkinsServices.setupBuildRecords(job.Id, '');
                System.assert(false, 'An Exception should have been thrown');
            } catch (Exception e) {
                System.assertEquals(System.Label.Jenkins_Job_Missing_Resource_Location_Error, e.getMessage(),
                    'The correct exception message should have been thrown');
            }
        Test.stopTest();
    }

    private static testMethod void createJenkinsBuild_ReusedBuild_InvalidReusedBuildId() {
        Boolean createRepo = true;
        TestingUtils.JenkinsJobSetup setup = new TestingUtils.JenkinsJobSetup(createRepo, UNIQUE_JENKINS_NAME_PREFIX);
        Jenkins_Job__c job = setup.jenkinsJob;

        Test.startTest();
            try {
                String newJBuildId = JenkinsServices.setupBuildRecords(job.Id, 'invalid-jbuild-id');
                System.assert(false,
                    'An exception should be thrown when createJenkinsBuild is passed an invalid build Id');
            } catch (Exception e) {
                System.assertEquals(System.Label.Jenkins_Job_Error_Invalid_Reused_Build, e.getMessage());
            }
        Test.stopTest();
    }

    private static testMethod void createJenkinsBuild_ReusedBuild_DeletedJenkinsBuild() {
        Boolean createRepo = true;
        TestingUtils.JenkinsJobSetup setup = new TestingUtils.JenkinsJobSetup(createRepo, UNIQUE_JENKINS_NAME_PREFIX);
        Jenkins_Job__c job = setup.jenkinsJob;

        Jenkins_Build__c jenkinsBuild = createJenkinsBuild(job.Id);
        Id deletedBuildId = jenkinsBuild.Id;
        delete jenkinsBuild;

        Test.startTest();
            try {
                String newJBuildId = JenkinsServices.setupBuildRecords(job.Id, deletedBuildId);
                System.assert(false,
                    'An exception should be thrown when createJenkinsBuild is passed an invalid build Id');
            } catch (Exception e) {
                System.assertEquals(System.Label.Jenkins_Job_Error_Invalid_Reused_Build, e.getMessage());
            }
        Test.stopTest();
    }

    private static testMethod void createJenkinsBuild_ReusedBuild_NoPackageURLThrowsException() {
        Boolean createRepo = false;
        TestingUtils.JenkinsJobSetup setup = new TestingUtils.JenkinsJobSetup(createRepo, UNIQUE_JENKINS_NAME_PREFIX);
        Jenkins_Job__c job = setup.jenkinsJob;

        Jenkins_Build__c previousSuccessfulBuild = TestingUtils.buildJenkinsBuild(job.Id);
        previousSuccessfulBuild.Package_URL__c = '';
        insert previousSuccessfulBuild;

        Test.startTest();
            try {
                String newJBuildId = JenkinsServices.setupBuildRecords(job.Id, previousSuccessfulBuild.Id);
                System.assert(false, 'An exception should be thrown by createJenkinsBuild');
            } catch (Exception e) {
                System.assertEquals(System.Label.Jenkins_Job_Error_Invalid_Reused_Build, e.getMessage(),
                    'The exception should have the correct message');
            }
        Test.stopTest();

        List<Jenkins_Build__c> newJBuilds =
            [SELECT Id, Package_URL__C, Reused_Build__c FROM Jenkins_Build__c WHERE Id !=: previousSuccessfulBuild.Id];
        System.assertEquals(0, newJBuilds.size(),
            'No new Jenkins Builds should have been created');

        System.assert([SELECT Id FROM Build__c].isEmpty(),
            'No builds should have been created when there is a previous successul Jenkins build');
    }

    private static testMethod void startJob_failsWhenNoAuthUser() {
        Test.setMock(HttpCalloutMock.class, new MockWebAssemblerAPI(MockWebAssemblerAPI.ASSEMBLE_ACTION));
        Boolean createRepo = true;
        TestingUtils.JenkinsJobSetup setup = new TestingUtils.JenkinsJobSetup(createRepo, UNIQUE_JENKINS_NAME_PREFIX);
        Id jBuildId = JenkinsServices.setupBuildRecords(setup.jenkinsJob.Id, '');
        TestingUtils.setupSSH();

        // create an auth user for tools
        Boolean isForTools = true;
        TestingUtils.createAuthUser(UserInfo.getUserId(), setup.ciInstance.Target_Instance__c, isForTools);

        Test.startTest();
            try {
                 JenkinsServices.startAssemblerJob(jBuildId);
            } catch (Exception e) {
                System.assert(false, 'No exception should be thrown. Caught: ' + e.getMessage());
            }
        Test.stopTest();

        Jenkins_Build__c jenkinsBuild = [SELECT Status__c, Status_Details__c FROM Jenkins_Build__c WHERE Id = :jBuildId];

        System.assertEquals(JenkinsServices.JENKINS_BUILD_FAILURE_STATUS, jenkinsBuild.Status__c,
                    'The jenkins build should be updated with a failure status');
        System.assertEquals(System.Label.Sightline_Instance_Not_Authorized_For_Assembler, jenkinsBuild.Status_Details__c,
                    'The jenkins build should be updated with the auth error details');
    }

    private static testMethod void startJob_failsWhenNoJenkinsConfig() {
        Boolean createRepo = true;
        TestingUtils.JenkinsJobSetup setup = new TestingUtils.JenkinsJobSetup(createRepo, UNIQUE_JENKINS_NAME_PREFIX);
        Id jBuildId = JenkinsServices.setupBuildRecords(setup.jenkinsJob.Id, '');

        Boolean isForTools = false;
        TestingUtils.createAuthUser(UserInfo.getUserId(), setup.ciInstance.Target_Instance__c, isForTools);

        delete setup.jenkinsConfig;

        Test.startTest();
            try {
                JenkinsServices.startAssemblerJob(jBuildId);
                System.assert(false, 'An Exception should have been thrown');
            } catch (Exception e) {
                System.assertEquals(JenkinsServices.CONFIG_ERROR, e.getMessage(),
                    'The correct exception message should have been thrown');
            }
        Test.stopTest();
    }

    private static testMethod void startJob_AssembleRequestIsMade() {
        Test.setMock(HttpCalloutMock.class, new MockWebAssemblerAPI(MockWebAssemblerAPI.ASSEMBLE_ACTION));

        Boolean createRepo = true;
        TestingUtils.JenkinsJobSetup setup = new TestingUtils.JenkinsJobSetup(createRepo, UNIQUE_JENKINS_NAME_PREFIX);
        Id jBuildId = JenkinsServices.setupBuildRecords(setup.jenkinsJob.Id, '');

        TestingUtils.setupSSH();

        // create a valid auth user
        Boolean isForTools = false;
        TestingUtils.createAuthUser(UserInfo.getUserId(), setup.ciInstance.Target_Instance__c, isForTools);

        Test.startTest();
            JenkinsServices.startAssemblerJob(jBuildId);
        Test.stopTest();

        Build__c updatedBuild = [SELECT Id, Status__c, UUID__c FROM Build__c WHERE Jenkins_Build__c =: jBuildId];

        System.assertEquals(MockWebAssemblerAPI.STATUS_RESULT, updatedBuild.Status__c,
            'The build should be updated with the status from the assemble response');
        System.assertEquals(MockWebAssemblerAPI.JOB_ID, updatedBuild.UUID__c,
            'The build should be updated with the job Id from the assemble response');

        Jenkins_Build__c jenkinsBuild = [
            SELECT Status__c, Status_Details__c FROM Jenkins_Build__c WHERE Id = :jBuildId ];

        System.assertEquals(JenkinsServices.JENKINS_SF_BUILD_IN_PROGRESS_STATUS, jenkinsBuild.Status__c,
                    'The jenkins build should be updated with an in progress status');
        System.assertEquals(true, String.isBlank(jenkinsBuild.Status_Details__c),
                    'The jenkins build status details should be blank');
    }

    private static testMethod void startJob_assemblerExceptionPopulatesStatusDetails() {
        Test.setMock(HttpCalloutMock.class, new MockWebAssemblerAPI(MockWebAssemblerAPI.ASSEMBLE_EXCEPTION_ACTION));

        Boolean createRepo = true;
        TestingUtils.JenkinsJobSetup setup = new TestingUtils.JenkinsJobSetup(createRepo, UNIQUE_JENKINS_NAME_PREFIX);
        setup.jenkinsJob.Ignore_Build_Errors__c = true;
        update setup.jenkinsJob;
        Id jBuildId = JenkinsServices.setupBuildRecords(setup.jenkinsJob.Id, '');

        TestingUtils.setupSSH();

        // create a valid auth user
        Boolean isForTools = false;
        TestingUtils.createAuthUser(UserInfo.getUserId(), setup.ciInstance.Target_Instance__c, isForTools);

        Test.startTest();
            JenkinsServices.startAssemblerJob(jBuildId);
        Test.stopTest();

        Build__c updatedBuild = [SELECT Id, Status__c, UUID__c FROM Build__c WHERE Jenkins_Build__c =: jBuildId];

        System.assertEquals(BuildServices.STATUS_FAILURE, updatedBuild.Status__c,
            'The build should be updated with a failure status when an exception is thrown');

        Jenkins_Build__c jenkinsBuild = [
            SELECT Status__c, Status_Details__c FROM Jenkins_Build__c WHERE Id = :jBuildId ];

        System.assertEquals(JenkinsServices.JENKINS_BUILD_FAILURE_STATUS, jenkinsBuild.Status__c,
                    'The jenkins build should be updated with a failure status');
        System.assertEquals(255, jenkinsBuild.Status_Details__c.length(),
                    'The jenkins build status details should be populated with an abbreviated message');
    }

    private static testMethod void deployBuildPackage_DeployRequestMade() {
        Boolean createRepo = true;
        TestingUtils.JenkinsJobSetup setup = new TestingUtils.JenkinsJobSetup(createRepo, UNIQUE_JENKINS_NAME_PREFIX);
        Id jBuildId = JenkinsServices.setupBuildRecords(setup.jenkinsJob.Id, '');
        Jenkins_Build__c jBuild = JenkinsServices.getJenkinsBuild(jBuildId);
        Build__c build = jBuild.Builds__r[0];

        TestingUtils.MockJenkinsBuildPackage buildPackage = new TestingUtils.MockJenkinsBuildPackage('testPackageContent', build.Id);

        Test.setMock(HttpCalloutMock.class, new MockWebAssemblerAPI(MockWebAssemblerAPI.JENKINS_DEPLOY_ACTION));

        Test.startTest();
            JenkinsServices.deployBuildPackage(jBuild.Id);
        Test.stopTest();

        jBuild = JenkinsServices.getJenkinsBuild(jBuildId);
        System.assertEquals(JenkinsServices.JENKINS_BUILD_PENDING_STATUS, jBuild.Status__c,
            'The Jenkins Build should have the correct status');
        System.assert(String.isBlank(jBuild.Status_Details__c),
            'The Jenkins Build should have the correct status details');

        System.assert(ExecuteJenkinsBuildbatchServices.isMonitorBatchScheduledOrRunning(),
            'A Jenkins Monitor Batch should be running or scheduled');
    }

    private static testMethod void deployBuildPackage_throwsExceptionWhenNoPackageURL() {
        Boolean createRepo = true;
        TestingUtils.JenkinsJobSetup setup = new TestingUtils.JenkinsJobSetup(createRepo, UNIQUE_JENKINS_NAME_PREFIX);
        Id jBuildId = JenkinsServices.setupBuildRecords(setup.jenkinsJob.Id, '');
        Jenkins_Build__c jBuild = JenkinsServices.getJenkinsBuild(jBuildId);
        Build__c build = jBuild.Builds__r[0];

        TestingUtils.MockJenkinsBuildPackage buildPackage = new TestingUtils.MockJenkinsBuildPackage('testPackageContent', build.Id);

        Test.setMock(HttpCalloutMock.class, new MockWebAssemblerAPI(MockWebAssemblerAPI.JENKINS_DEPLOY_ACTION));

        Test.startTest();
            JenkinsServices.deployBuildPackage(jBuild.Id);
        Test.stopTest();

        jBuild = JenkinsServices.getJenkinsBuild(jBuildId);
        System.assertEquals(JenkinsServices.JENKINS_BUILD_PENDING_STATUS, jBuild.Status__c,
            'The Jenkins Build should have the correct status');
        System.assert(String.isBlank(jBuild.Status_Details__c),
            'The Jenkins Build should have the correct status details');
    }

    private static testMethod void deployBuildPackage_DeployRequestFails_WebAssemblerReturnsError() {
        Boolean createRepo = true;
        TestingUtils.JenkinsJobSetup setup = new TestingUtils.JenkinsJobSetup(createRepo, UNIQUE_JENKINS_NAME_PREFIX);
        Id jBuildId = JenkinsServices.setupBuildRecords(setup.jenkinsJob.Id, '');
        Jenkins_Build__c jBuild = JenkinsServices.getJenkinsBuild(jBuildId);

        Test.setMock(HttpCalloutMock.class, new MockWebAssemblerAPI(MockWebAssemblerAPI.JENKINS_DEPLOY_FAILURE_ACTION));

        Test.startTest();
            JenkinsServices.deployBuildPackage(jBuild.Id);
        Test.stopTest();

        jBuild = JenkinsServices.getJenkinsBuild(jBuildId);
        System.assertEquals(JenkinsServices.JENKINS_BUILD_FAILURE_STATUS, jBuild.Status__c,
            'The Jenkins Build should have the correct status');

        System.assert( jBuild.Status_Details__c.contains(MockWebAssemblerAPI.FAILURE_REASON),
            'The Jenkins Build should have the correct status details');

        System.assert( !ExecuteJenkinsBuildbatchServices.isMonitorBatchScheduledOrRunning(),
            'A Jenkins Monitor Batch should NOT be running or scheduled');
    }
}
