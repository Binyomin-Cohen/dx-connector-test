@isTest
private class TestBuildServices {

    private static Release__c release;

    private static void setup() {
        release = new Release__c(Name='Test release');
        insert release;
    }

    static testMethod void getNewlyFinishedBuilds() {
    	setup();

    	Build__c newBuild1 = TestingUtils.createBuild(release.Id, BuildServices.STATUS_IN_PROGRESS);
    	Build__c newBuild2 = TestingUtils.createBuild(release.Id, BuildServices.STATUS_IN_PROGRESS);

    	Map<Id, Build__c> oldMap = new Map<Id, Build__c>{ newBuild1.Id => newBuild1, newBuild2.Id => newBuild2 };

    	Build__c updatedBuild1 = newBuild1.clone(true, true);
    	updatedBuild1.Status__c = BuildServices.STATUS_SUCCESS;

    	Build__c updatedBuild2 = newBuild2.clone(true, true);
    	updatedBuild2.Status__c = BuildServices.STATUS_FAILURE;

        List<Build__c> newBuilds = new List<Build__c> {updatedBuild1, updatedBuild2};

        Test.startTest();

        	List<Build__c> finishedBuilds = BuildServices.getNewlyFinishedBuilds(oldMap, newBuilds);

        Test.stopTest();

        System.assertEquals(2, finishedBuilds.size(), 'All newly finished builds should be returned');
        System.assertEquals(updatedBuild1.Id, finishedBuilds[0].Id, 'Builds with an updated status of success should be returned');
        System.assertEquals(updatedBuild2.Id, finishedBuilds[1].Id, 'Builds with an updated status of failure should be returned');
    }

    static testMethod void getNewlyFinishedBuilds_noneFinished() {
    	setup();

    	Build__c newBuild1 = TestingUtils.createBuild(release.Id, BuildServices.STATUS_IN_PROGRESS);
    	Build__c newBuild2 = TestingUtils.createBuild(release.Id, BuildServices.STATUS_SUCCESS);
        List<Build__c> newBuilds = new List<Build__c> {newBuild1, newBuild2};

    	Map<Id, Build__c> oldMap = new Map<Id, Build__c>(newBuilds);

        Test.startTest();

        	List<Build__c> finishedBuilds = BuildServices.getNewlyFinishedBuilds(oldMap, newBuilds);

        Test.stopTest();

        System.assertEquals(0, finishedBuilds.size(), 'Only newly finished builds should be returned');
    }

    static testMethod void getDeploymentAttemptsToStart_NoDeployment() {
    	setup();

    	Build__c build = TestingUtils.createBuild(release.Id, BuildServices.STATUS_SUCCESS);

    	Test.startTest();

    	   Set<Id> attemptsToStart = BuildServices.getDeploymentAttemptsToStart(new List<Build__c>{build});

    	Test.stopTest();

    	System.assertEquals(0, attemptsToStart.size(), 'Only builds that are currently on a deployment are deployable');
    }

    static testMethod void getDeploymentAttemptsToStart_deploymentInProgress() {
    	setup();

    	Build__c build = TestingUtils.createBuild(release.Id, BuildServices.STATUS_SUCCESS);

    	Deployment_Attempt__c attempt = new Deployment_Attempt__c(Build__c = build.Id, Status__c = DeploymentServices.STATUS_IN_PROGRESS);
    	insert attempt;

    	Deployment__c deployment = new Deployment__c(Name='Background Build');
    	deployment.Build__c = build.Id;
    	deployment.Deployment_Attempt__c = attempt.Id;
    	insert deployment;

    	Test.startTest();

    	   Set<Id> attemptsToStart = BuildServices.getDeploymentAttemptsToStart(new List<Build__c>{build});

    	Test.stopTest();

    	System.assertEquals(0, attemptsToStart.size(), 'Only deployment attempts that are not started are deployable');
    }

    static testMethod void getDeploymentAttemptsToStart() {
    	setup();

    	Build__c build = TestingUtils.createBuild(release.Id, BuildServices.STATUS_SUCCESS);

    	Deployment_Attempt__c attempt = new Deployment_Attempt__c(Build__c = build.Id, Status__c = DeploymentServices.STATUS_NOT_STARTED);
    	insert attempt;

    	Deployment__c deployment = new Deployment__c(Name='Background Build');
    	deployment.Build__c = build.Id;
    	deployment.Deployment_Attempt__c = attempt.Id;
    	insert deployment;

    	Test.startTest();

    	   Set<Id> attemptsToStart = BuildServices.getDeploymentAttemptsToStart(new List<Build__c>{build});

    	Test.stopTest();

    	System.assertEquals(1, attemptsToStart.size(), 'Deployment attempts that have a deployment and are not started are deployable');
    	System.assert(attemptsToStart.contains(attempt.Id), 'The deployment attempt for the completed build should be returned');
    }

    static testMethod void updateDeploymentWithCompletedBuild() {
        setup();

        Build__c build = TestingUtils.createBuild(release.Id, BuildServices.STATUS_SUCCESS);

        Deployment__c deployment = new Deployment__c(Name='Background Build');
        deployment.Build__c = build.Id;
        insert deployment;

        Test.startTest();

            BuildServices.updateDeploymentWithCompletedBuild( new List<Build__c>{ build } );

        Test.stopTest();

        Deployment__c updatedDeployment = [SELECT Id, Completed_Build__c FROM Deployment__c];

        System.assertEquals(build.Id, updatedDeployment.Completed_Build__c, 'The deployment should be updated with the completed build');
    }

    static testMethod void updateDeploymentWithCompletedBuild_noDeployment() {
        setup();

        Build__c build = TestingUtils.createBuild(release.Id, BuildServices.STATUS_SUCCESS);

        Deployment__c deployment = new Deployment__c(Name='Background Build');
        insert deployment;

        Test.startTest();

            BuildServices.updateDeploymentWithCompletedBuild( new List<Build__c>{ build } );

        Test.stopTest();

        Deployment__c updatedDeployment = [SELECT Id, Completed_Build__c FROM Deployment__c];

        System.assertEquals(null, updatedDeployment.Completed_Build__c, 'The deployment should be unchanged');
    }

    static testMethod void updateDeploymentWithCompletedBuild_JenkinsDeployment() {
        // TODO: throws null pointer when false. Investigate
        Boolean createRepo = true;
        TestingUtils.JenkinsJobSetup setup = new TestingUtils.JenkinsJobSetup(createRepo, 'testingBuildTrigger');
        Id jBuildId = JenkinsServices.setupBuildRecords(setup.jenkinsJob.Id, '');
        Jenkins_Build__c jBuild = JenkinsServices.getJenkinsBuild(jBuildId);
        Build__c build = jBuild.Builds__r[0];

        TestingUtils.MockJenkinsBuildPackage buildPackage =
            new TestingUtils.MockJenkinsBuildPackage('testPackageContent', build.Id);

        Test.setMock(HttpCalloutMock.class, new MockWebAssemblerAPI(MockWebAssemblerAPI.JENKINS_DEPLOY_ACTION));

        Test.startTest();
            update new Build__c(Id=build.Id, Status__c = BuildServices.STATUS_SUCCESS);
        Test.stopTest();

        jBuild = JenkinsServices.getJenkinsBuild(jBuildId);
        System.assertEquals(JenkinsServices.JENKINS_BUILD_PENDING_STATUS, jBuild.Status__c,
            'The Jenkins Build should have the correct status');
        System.assert(String.isBlank(jBuild.Status_Details__c), 'The Jenkins Build should have empty status details');
        System.assertEquals(jBuild.Builds__r[0].Package_URL__c, jBuild.Package_URL__c, 'The Jenkins Build should have the build package url populated from the build');

        System.assert(ExecuteJenkinsBuildbatchServices.isMonitorBatchScheduledOrRunning(),
            'A Jenkins Monitor Batch should be running or scheduled');
    }

    static testMethod void updateDeploymentWithCompletedBuild_JenkinsDeployment_FailureWithBuildWarnings() {
        // set up build and related objects that will NOT ignore build warnings
        Jenkins_Job__c jJob = TestingUtils.createJenkinsJob();
        jJob.Ignore_Build_Errors__c = false;
        update jJob;

        Jenkins_Build__c jBuild = new Jenkins_Build__c(Jenkins_Job__c=jJob.Id);
        insert jBuild;

        Build__c build = new Build__c(Jenkins_Build__c=jBuild.Id, Status__c=BuildServices.STATUS_PENDING);
        insert build;

        ALM_Error__c buildError = TestingUtils.buildAssemblerBuildError(build.Id);
        insert buildError;

        Test.startTest();
            try {
                build.Status__c = BuildServices.STATUS_SUCCESS;
                update build;
            } catch (Exception e) {
                System.assert(false, 'No exception should have been thrown');
            }
        Test.stopTest();

        jBuild = [SELECT Id, Status__c, Status_Details__c from Jenkins_Build__c WHERE Id =: jBuild.Id];
        System.assertEquals(jenkinsServices.JENKINS_BUILD_FAILURE_STATUS, jBuild.Status__c,
                            'The Status on the Jenkins Build should be correct');
        System.assertEquals(System.Label.Jenkins_Build_Assembler_Failure_Errors_Not_Ignored, jBuild.Status_Details__c,
                            'The Status Details on the Jenkins Build should be correct');
    }

    static testMethod void updateDeploymentWithCompletedBuild_JenkinsDeployment_SuccessWithBuildWarnings() {
        // set up build and related objects that WILL ignore build warnings
        Boolean createRepo = true;
        TestingUtils.JenkinsJobSetup setup = new TestingUtils.JenkinsJobSetup(createRepo, 'testingBuildTrigger');

        setup.jenkinsJob.Ignore_Build_Errors__c = true;
        update setup.jenkinsJob;

        Jenkins_Build__c jBuild = new Jenkins_Build__c(Jenkins_Job__c=setup.jenkinsJob.Id);
        insert jBuild;

        Build__c build = new Build__c(Jenkins_Build__c=jBuild.Id, Status__c=BuildServices.STATUS_PENDING);
        insert build;

        ALM_Error__c buildError = TestingUtils.buildAssemblerBuildError(build.Id);
        insert buildError;

        TestingUtils.MockJenkinsBuildPackage buildPackage =
            new TestingUtils.MockJenkinsBuildPackage('testPackageContent', build.Id);

        Test.setMock(HttpCalloutMock.class, new MockWebAssemblerAPI(MockWebAssemblerAPI.JENKINS_DEPLOY_ACTION));

        Test.startTest();
            try {
                build.Status__c = BuildServices.STATUS_SUCCESS;
                update build;
            } catch (Exception e) {
                System.assert(false, 'No exception should have been thrown');
            }
        Test.stopTest();

        jBuild = [SELECT Id, Status__c, Status_Details__c from Jenkins_Build__c WHERE Id =: jBuild.Id];
        System.assertEquals(jenkinsServices.JENKINS_BUILD_PENDING_STATUS, jBuild.Status__c,
                            'The Status on the Jenkins Build should be correct');
        System.assertEquals(System.Label.Jenkins_Build_Assembler_Warning_Errors_Ignored, jBuild.Status_Details__c,
                            'The Status Details on the Jenkins Build should be correct');
    }


    static testMethod void getMostRecentBuildPackage() {
        Build__c build = new Build__c();
        insert build;

        Attachment oldestBuildPackage = new TestingUtils.MockJenkinsBuildPackage('p2', build.Id, Datetime.now().addDays(-1)).buildPackage;
        Attachment newestBuildPackage = new TestingUtils.MockJenkinsBuildPackage('p1', build.Id, Datetime.now()).buildPackage;
        Attachment targetBackup = new TestingUtils.MockJenkinsBuildPackage('backup', build.Id).buildPackage;
        targetBackup.Name = targetBackup.Name.replace('.zip', '-target.zip');
        update targetBackup;

        Attachment queriedBuildPackage;
        Test.startTest();
            queriedBuildPackage = BuildServices.getLatestBuildPackage(build.Id);
        Test.stopTest();

        System.assertEquals(newestBuildPackage.Id, queriedBuildPackage.Id, 'The newest build package should be returned');
    }
}
