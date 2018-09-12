@isTest
private with sharing class TestJenkinsJobExt {

    private static final String UNIQUE_JENKINS_NAME_PREFIX = 'TestJenkinsJobExt';
    private static final String TEST_JOB_NAME = 'Test Jenkins Job';
    private static final String TEST_JOB_PATH = 'test/job/path';
    private static final String TEST_JOB_TOKEN = 'test_job_token';
    private static final String VALID_FIELD_NAME = SObjectServices.getFullyQualifiedName('Pre_Steps_Completed__c');

    private static Release__c testRelease;
    private static Instances__c testInstance;
    private static JenkinsJobExt controller;

    private static void setup() {
        testRelease = new Release__c(Name = 'Test Release Name');
        insert testRelease;

        testInstance = TestingUtils.createInstance('Test Instance Name');
    }

    private static void initializeJenkinsJobControllerWithPermissions( User runningUser ) {

        if (!TestingUtils.isUserAssignedToPermissionSet(runningUser.Id, TestingUtils.ALM_ADMIN_ACCESS_PERMISSION_SET.Id)) {
            insert new PermissionSetAssignment(AssigneeId=runningUser.Id, PermissionSetId=TestingUtils.ALM_ADMIN_ACCESS_PERMISSION_SET.Id);
        }
        System.runAs(runningUser) {
            ApexPages.StandardController sc = new ApexPages.StandardController(new Jenkins_Job__c());
            controller = new JenkinsJobExt(sc);
        }
    }

    private static Jenkins_Job__c createJenkinsJob(String jobName, String path, String token, Instances__c instance, Release__c release) {
        CI_Instance__c ciInstance = new CI_Instance__c(Name='test', Target_Instance__c = instance.Id, Release__c = release.Id);
        insert ciInstance;

        Jenkins_Job__c jenkinsJob = new Jenkins_Job__c(
            Name = jobName,
            Path__c = path,
            Token__c = token,
            CI_Instance__c = ciInstance.Id,
            Release__c = release.Id
        );
        insert jenkinsJob;
        return jenkinsJob;
    }

    private static testMethod void createJenkinsBuildFails_NoReusedBuildOrRepo() {
        setup();
        Jenkins_Job__c job = createJenkinsJob(TEST_JOB_NAME, TEST_JOB_PATH, TEST_JOB_TOKEN, testInstance, testRelease);

        Test.startTest();
            try {
                String buildId = JenkinsJobExt.createJenkinsBuild(job.Id, '');
                System.assert(false,
                    'An exception should be thrown when no repo, and no Jenkins Build is specificed for reuse');
            } catch (Exception ae) {
                System.assert(ae instanceof AuraHandledException,
                    'An Aura Handled exception should be thrown when no repo, and no Jenkins Build is specificed for reuse');
            }
        Test.stopTest();

        List<Jenkins_Build__c> builds = [SELECT Id FROM Jenkins_Build__c];
        System.assert(builds.isEmpty(),
            'No Jenkins Build should be created when no repo, and no Jenkins Build is specificed for reuse');
    }

    private static testMethod void createJenkinsBuild_validatesBuildRule() {
        setup();
        Jenkins_Job__c job = TestingUtils.buildJenkinsJob(testInstance.Id, testRelease.Id);

        Build_Rule__c rule = new Build_Rule__c();
        rule.Boolean_Criteria__c = VALID_FIELD_NAME;
        insert rule;

        job.Build_Rule__c = rule.Id;
        insert job;

        Test.startTest();
            try {
                JenkinsJobExt.createJenkinsBuild(job.Id, '');
                System.assert(false, 'An exception should be thrown when the job build rule criteria are not met');
            } catch(Exception ae) {
                System.assert(ae instanceof AuraHandledException, 'An AuraHandledException should be thrown when the job build rule criteria are not met');
            }
        Test.stopTest();
    }

    private static testMethod void getBuildRuleCriteria_noCriteria() {
        setup();
        Jenkins_Job__c job = TestingUtils.createJenkinsJob(testInstance.Id, testRelease.Id);

        Test.startTest();

            List<JenkinsJobExt.BuildRuleCriterion> criteria = JenkinsJobExt.getBuildRuleCriteria(job.Id);

        Test.stopTest();

        System.assertEquals(0, criteria.size(), 'The defined build rules should be returned');
    }

    private static testMethod void getBuildRuleCriteria_invalidCriterion() {
        setup();
        Jenkins_Job__c job = TestingUtils.buildJenkinsJob(testInstance.Id, testRelease.Id);

        Build_Rule__c rule = new Build_Rule__c();
        rule.Boolean_Criteria__c = VALID_FIELD_NAME;
        insert rule;

        job.Build_Rule__c = rule.Id;
        insert job;

        Test.startTest();

            List<JenkinsJobExt.BuildRuleCriterion> criteria = JenkinsJobExt.getBuildRuleCriteria(job.Id);

        Test.stopTest();

        System.assertEquals(1, criteria.size(), 'The defined build rules should be returned');
        String fieldLabel = CI_Instance__c.SObjectType.getDescribe().fields.getMap().get(VALID_FIELD_NAME).getDescribe().getLabel();
        String expectedLabel = fieldLabel + ' (' + VALID_FIELD_NAME + ')';
        System.assertEquals(expectedLabel, criteria[0].label, 'The build rule label should include the field label and api name');
        System.assertEquals(false, criteria[0].value, 'The value should match the field value from the CI Instance');
    }

    private static testMethod void getBuildRuleCriteria_validCriterion() {
        setup();
        Jenkins_Job__c job = TestingUtils.buildJenkinsJob(testInstance.Id, testRelease.Id);

        Build_Rule__c rule = new Build_Rule__c();
        rule.Boolean_Criteria__c = VALID_FIELD_NAME;
        insert rule;

        job.Build_Rule__c = rule.Id;
        insert job;

        CI_Instance__c instance = new CI_Instance__c(Id=job.CI_Instance__c);
        instance.put(VALID_FIELD_NAME, true);
        update instance;

        Test.startTest();

            List<JenkinsJobExt.BuildRuleCriterion> criteria = JenkinsJobExt.getBuildRuleCriteria(job.Id);

        Test.stopTest();

        System.assertEquals(1, criteria.size(), 'The defined build rules should be returned');
        String fieldLabel = CI_Instance__c.SObjectType.getDescribe().fields.getMap().get(VALID_FIELD_NAME).getDescribe().getLabel();
        String expectedLabel = fieldLabel + ' (' + VALID_FIELD_NAME + ')';
        System.assertEquals(expectedLabel, criteria[0].label, 'The build rule label should include the field label and api name');
        System.assertEquals(true, criteria[0].value, 'The value should match the field value from the CI Instance');
    }

    private static testMethod void getExistingSuccessfulBuildsForRelease() {
        setup();
        Jenkins_Job__c job = createJenkinsJob(TEST_JOB_NAME, TEST_JOB_PATH, TEST_JOB_TOKEN, testInstance, testRelease);

        List<Jenkins_Build__c> reusableJenkinsBuilds = new List<Jenkins_Build__c> {
            new Jenkins_Build__c(Jenkins_Job__c=job.Id, Status__c='SUCCESS', Package_URL__c='http://test.com')
        };
        List<Jenkins_Build__c> otherJenkinsBuilds = new List<Jenkins_Build__c> {
            new Jenkins_Build__c(Jenkins_Job__c=job.Id, Status__c='SUCCESS'),
            new Jenkins_Build__c(Jenkins_Job__c=job.Id, Status__c='PENDING')
        };

        List<Jenkins_Build__c> allJenkinsBuilds = new List<Jenkins_Build__c>();
        allJenkinsBuilds.addAll(reusableJenkinsBuilds);
        allJenkinsBuilds.addAll(otherJenkinsBuilds);
        insert allJenkinsBuilds;

        Test.startTest();
            List<JenkinsJobExt.JenkinsBuild> actualReusables =
                    JenkinsJobExt.getExistingSuccessfulBuildsForRelease(testRelease.Id);
        Test.stopTest();

        System.assertEquals(1, actualReusables.size(),
            'There should be one reusable Jenkins builds');

        System.assertEquals(actualReusables[0].Id, reusableJenkinsBuilds[0].Id,
            'The Jenkins build returned from getExistingSuccessfulBuildsForRelease should be correct');
    }

    private static testMethod void getExistingSuccessfulBuildsForRelease_withDifferentReleases() {
        setup();

        Release__c secondRelease = new Release__c(Name = 'Second Release Name');
        insert secondRelease;
        Instances__c secondInstance = TestingUtils.createInstance('Second Instance Name');

        Jenkins_Job__c job = createJenkinsJob(TEST_JOB_NAME, TEST_JOB_PATH, TEST_JOB_TOKEN, testInstance, testRelease);
        Jenkins_Job__c secondJob = createJenkinsJob('Second Jenkins Job', TEST_JOB_PATH, TEST_JOB_TOKEN,
                                                    secondInstance, secondRelease);

        List<Jenkins_Build__c> reusableJenkinsBuilds = new List<Jenkins_Build__c> {
            new Jenkins_Build__c( Jenkins_Job__c = job.Id, Status__c = 'SUCCESS', Package_URL__c='http://test.com'),
            new Jenkins_Build__c( Jenkins_Job__c = job.Id, Status__c = 'SUCCESS', Package_URL__c='http://test2.com')
        };
        List<Jenkins_Build__c> otherJenkinsBuilds = new List<Jenkins_Build__c> {
            new Jenkins_Build__c( Jenkins_Job__c = secondJob.Id, Status__c = 'SUCCESS', Package_URL__c='http://test.com'),
            new Jenkins_Build__c( Jenkins_Job__c = secondJob.Id, Status__c = 'SUCCESS', Package_URL__c='http://test2.com'),
            new Jenkins_Build__c( Jenkins_Job__c = secondJob.Id, Status__c = 'FAILURE', Package_URL__c='http://test.com'),
            new Jenkins_Build__c( Jenkins_Job__c = job.Id, Status__c = 'SUCCESS')
        };

        List<Jenkins_Build__c> allJenkinsBuilds = new List<Jenkins_Build__c>();
        allJenkinsBuilds.addAll(reusableJenkinsBuilds);
        allJenkinsBuilds.addAll(otherJenkinsBuilds);
        insert allJenkinsBuilds;

        Test.startTest();
            List<JenkinsJobExt.JenkinsBuild> actualReusables =
                    JenkinsJobExt.getExistingSuccessfulBuildsForRelease(testRelease.Id);
        Test.stopTest();

        System.assertEquals(reusableJenkinsBuilds.size(), actualReusables.size(),
            'There should be the correct number of reusable Jenkins builds');

        Set<Id> actualReusablesIds = new Set<Id>();
        for (JenkinsJobExt.JenkinsBuild jb : actualReusables){
            actualReusablesIds.add(jb.Id);
        }
        System.assert(actualReusablesIds.equals(Pluck.ids(reusableJenkinsBuilds)),
            'Jenkins builds returned from getExistingSuccessfulBuildsForRelease should be correct');
    }

    private static testMethod void createJenkinsBuild_buildRecordsAreCreated() {
        Boolean createRepo = true;
        TestingUtils.JenkinsJobSetup setup = new TestingUtils.JenkinsJobSetup(createRepo, UNIQUE_JENKINS_NAME_PREFIX);
        Jenkins_Job__c job = setup.jenkinsJob;

        Test.startTest();
            String buildId = JenkinsJobExt.createJenkinsBuild(job.Id, '');
        Test.stopTest();

        // Assert on Jenkins Build
        List<Jenkins_Build__c> jenkinsBuilds = [SELECT Id, Jenkins_Job__c, CI_Instance__c, Reused_Build__c
                                                 FROM Jenkins_Build__c WHERE Id = :buildId];
        System.assertEquals(1, jenkinsBuilds.size(), 'A jenkins build should be created for the given jenkins job Id');

        Jenkins_Build__c jBuild = jenkinsBuilds[0];
        System.assertEquals(job.Id, jBuild.Jenkins_Job__c,
            'The Jenkins Job Id should be populated on the created jenkins build');
        System.assertEquals(job.CI_Instance__c, jBuild.CI_Instance__c,
            'The CI Instance should be populated on the created jenkins build');
        System.assert(String.isEmpty(jBuild.Reused_Build__c),
           'The Jenkins Build Template should be Empty');

        // Assert on Build
        List<Build__c> builds = [SELECT Id, Jenkins_Build__c, Source_Repository_Location__c, Source_Repository__c,
                                    Status__c, Target__c, Release__c
                                 FROM Build__c WHERE Jenkins_Build__c = :jBuild.Id];
        System.assertEquals(1, builds.size(), 'A build should be created for the Jenkins build');

        Build__c build = builds[0];
        System.assertEquals(jBuild.Id, build.Jenkins_Build__c, 'The Jenkins Build should be correctly set on the Build');
        System.assertEquals(setup.instance.Id, build.Target__c, 'The target instance should be set correctly');
        System.assertEquals(setup.jenkinsJob.Release__c, build.Release__c, 'The Release should be correctly set on the Build');
        System.assertEquals(setup.branchName, build.Source_Repository_Location__c,
            'The Source Repo Location should be correctly set on the Build');
        System.assertEquals(setup.vcRepo.Id, build.Source_Repository__c,
            'The VC Repo should be correctly set on the Build');
        System.assertEquals(BuildServices.STATUS_NOT_STARTED, build.Status__c, 'The status should be set correctly');
    }

    private static testMethod void createJenkinsBuild_ReusedBuild_copiesPackageURL() {
        Boolean createRepo = true;
        TestingUtils.JenkinsJobSetup setup = new TestingUtils.JenkinsJobSetup(createRepo, UNIQUE_JENKINS_NAME_PREFIX);
        Jenkins_Job__c job = setup.jenkinsJob;

        Jenkins_Build__c previousSuccessfulBuild = TestingUtils.buildJenkinsBuild(job.Id);
        previousSuccessfulBuild.Package_URL__c = 'https://some-jenkins-server.com';
        insert previousSuccessfulBuild;

        Test.startTest();
            String newJBuildId = JenkinsJobExt.createJenkinsBuild(job.Id, previousSuccessfulBuild.Id);
        Test.stopTest();

        List<Jenkins_Build__c> newJBuilds =
            [SELECT Id, Package_URL__C, Reused_Build__c FROM Jenkins_Build__c WHERE Id=:newJBuildId];

        System.assertEquals(1, newJBuilds.size(),
            'A jenkins build should be created in addition to the previously successful build');

        System.assertEquals(previousSuccessfulBuild.Id, newJBuilds[0].Reused_Build__c,
            'The Id of the reused build should have been copied to the new build');

        System.assertEquals(previousSuccessfulBuild.Package_URL__c, newJBuilds[0].Package_URL__c,
            'The package url of the reused build should have been copied to the new build');

        System.assert([SELECT Id FROM Build__c].isEmpty(),
            'No builds should have been created when there is a previous successul Jenkins build');
    }

    private static testMethod void startJob_AssembleRequestIsMade() {
        Test.setMock(HttpCalloutMock.class, new MockWebAssemblerAPI(MockWebAssemblerAPI.ASSEMBLE_ACTION));

        Boolean createRepo = true;
        TestingUtils.JenkinsJobSetup setup = new TestingUtils.JenkinsJobSetup(createRepo, UNIQUE_JENKINS_NAME_PREFIX);
        TestingUtils.setupSSH();

        Jenkins_Job__c job = setup.jenkinsJob;
        String jBuildId = JenkinsJobExt.createJenkinsBuild(job.Id, '');

        Boolean isForTools = false;
        TestingUtils.createAuthUser(UserInfo.getUserId(), setup.ciInstance.Target_Instance__c, isForTools);

        PageMessage response;
        Test.startTest();
            response = JenkinsJobExt.startJob(jBuildId);
        Test.stopTest();

        System.assert(response.message.containsIgnoreCase('started'),
            'startJob should return a Message indicating success. Intead, it was: ' + response.message);
        System.assert(response.messageType.containsIgnoreCase(ApexPages.Severity.INFO.name()),
            'startJob should return a Page Message with INFO Severity. Intead, it was: ' + response.messageType);

        List<Build__c> builds = [SELECT UUID__c, Status__c From Build__c where Jenkins_Build__c =: jBuildId];
        System.assertEquals(1, builds.size(), 'A build should be created for the Jenkins build');

        Build__c build = builds[0];

        System.assertEquals(MockWebAssemblerAPI.JOB_ID, build.UUID__c,
            'The build should be updated with the job Id from the assemble response');
        System.assertEquals(MockWebAssemblerAPI.STATUS_RESULT, build.Status__c,
            'The build should be updated with the status from the assemble response');
    }

    private static testMethod void startJob_ReusedBuildPackage_SkipsAssembleWhenPackageURLExists() {
        Test.setMock(HttpCalloutMock.class, new MockWebAssemblerAPI(MockWebAssemblerAPI.JENKINS_DEPLOY_ACTION));

        Boolean createRepo = true;
        TestingUtils.JenkinsJobSetup setup = new TestingUtils.JenkinsJobSetup(createRepo, UNIQUE_JENKINS_NAME_PREFIX);
        TestingUtils.setupSSH();

        Jenkins_Job__c job = setup.jenkinsJob;
        Jenkins_Build__c jBuild = TestingUtils.buildJenkinsBuild(job.Id);
        jBuild.Package_URL__c = 'https://some-jenkins-server.com';
        insert jBuild;

        PageMessage response;
        Test.startTest();
            response = JenkinsJobExt.startJob(jBuild.Id);
        Test.stopTest();

        System.assert( MockWebAssemblerAPI.jenkinsDeployRequestWasMade, 'A deployment request should have been made' );
        System.assert( !MockWebAssemblerAPI.assembleRequestWasMade, 'No assemble request should have been made' );

        System.assert([SELECT Id FROM Build__c].isEmpty(),
                    'No builds should have been created when there is a previous successul Jenkins build');

        System.assert(response.messageType.containsIgnoreCase(ApexPages.Severity.INFO.name()),
            'startJob should return a Page Message with INFO Severity. Intead, it was: ' + response.messageType);

        System.assert(response.message.containsIgnoreCase('started'),
            'startJob should return a Message indicating that start job was successful. Instead it was: '
            + response.message);

        jBuild = JenkinsServices.getJenkinsBuild(jBuild.Id);
        System.assertEquals(JenkinsServices.JENKINS_BUILD_PENDING_STATUS, jBuild.Status__c,
            'The Jenkins build should be a pending');
    }

    static testMethod void testPermissions_adminUser() {
        Profile standardUserProfile = [SELECT Id FROM Profile WHERE Name='Standard User'];
        User potentialAdminUser = TestingUtils.createUser(standardUserProfile.Id);

        Test.startTest();
            initializeJenkinsJobControllerWithPermissions(potentialAdminUser);
        Test.stopTest();

        System.assert(!ApexPages.hasMessages(), 'No error message should be shown');

    }

    static testMethod void testPermissions_nonAdminUser() {
        Profile standardUserProfile = [SELECT Id FROM Profile WHERE Name='Standard User'];
        User nonAdminUser = TestingUtils.buildUser(standardUserProfile.Id);

        Test.startTest();
            System.runAs(nonAdminUser) {
                ApexPages.StandardController sc = new ApexPages.StandardController(new Jenkins_Job__c());
                controller = new JenkinsJobExt(sc);
            }
        Test.stopTest();

        System.assert(TestingUtils.pageMessageContains(System.Label.Permissions_Error), 'The correct error message should be shown');

    }
}
