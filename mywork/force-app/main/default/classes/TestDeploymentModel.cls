@isTest
private class TestDeploymentModel {

    static Release__c release;
    static Instances__c instance;

    //Monday, February 5, 2018 11:22:23 AM (US EST GMT-05:00)
    static final Long END_DATE = 1517847743000L;
    //Saturday, February 3, 2018 10:22:23 PM (US EST GMT-05:00)
    static final Long START_DATE = 1517714543000L;

    static void setup() {
        release = new Release__c(Name='Sprint 15');
        insert release;

        instance = new Instances__c(Name='dev', Type__c='Production / Developer');

        insert instance;
    }

    static testMethod void datetimeFields_formatObservesLocale_US() {
        User user = TestingUtils.createUser(TestingUtils.ADMIN_USER.ProfileId, 'us-user@sightline-test.com');
        user.localesidkey = 'en_US';
        user.timezonesidkey = 'America/New_York';
        update user;

        System.runAs(user) {
            Deployment_Attempt__c deployAttempt = setupDeploymentAttemptWithDateTimes();

            Test.startTest();
                DeploymentModel.Attempt actualModel = new DeploymentModel.Attempt(deployAttempt);
            Test.stopTest();

            System.assertEquals('2/3/2018 10:22 PM', actualModel.startTime, 'The start time should be formatted into the users locale');
            System.assertEquals('2/5/2018 11:22 AM', actualModel.endTime, 'The end time should be formatted into the users locale');
        }
    }
 
    static testMethod void datetimeFields_formatObservesLocale_GB() {
        User user = TestingUtils.createUser(TestingUtils.ADMIN_USER.ProfileId, 'gb-user@sightline-test.com');
        user.localesidkey = 'en_GB';
        user.timezonesidkey = 'America/New_York';
        update user;

        System.runAs(user) {
            Deployment_Attempt__c deployAttempt = setupDeploymentAttemptWithDateTimes();

            Test.startTest();
                DeploymentModel.Attempt actualModel = new DeploymentModel.Attempt(deployAttempt);
            Test.stopTest();

            System.assertEquals('03/02/2018 22:22', actualModel.startTime, 'The start time should be formatted into the users locale');
            System.assertEquals('05/02/2018 11:22', actualModel.endTime, 'The end time should be formatted into the users locale');
        }
    }
 
    static testMethod void datetimeFields_formatObservesLocaleAndTimezone() {
        User user = TestingUtils.createUser(TestingUtils.ADMIN_USER.ProfileId, 'de-user@sightline-test.com');
        user.localesidkey = 'de_DE';
        user.timezonesidkey = 'America/Los_Angeles';
        update user;

        System.runAs(user) {
            Deployment_Attempt__c deployAttempt = setupDeploymentAttemptWithDateTimes();

            Test.startTest();
                DeploymentModel.Attempt actualModel = new DeploymentModel.Attempt(deployAttempt);
            Test.stopTest();

            System.assertEquals('03.02.2018 19:22', actualModel.startTime, 'The start time should be formatted into the users locale and timezone');
            System.assertEquals('05.02.2018 08:22', actualModel.endTime, 'The end time should be formatted into the users locale and timezone');
        }
    }

    static Deployment_Attempt__c setupDeploymentAttemptWithDateTimes() {
        setup();
        Integer totalLines = 0;
        Integer totalTests = 0;
        Integer codeCoverage = 0;
        Boolean runTests = false;

        Deployment_Attempt__c deployAttempt = TestingUtils.createDeploymentAttempt(release.Id, instance.Id,
                                                                                totalLines, totalTests, codeCoverage, runTests);

        deployAttempt.Start_Date__c = Datetime.newInstance(START_DATE);
        deployAttempt.End_Date__c = Datetime.newInstance(END_DATE);
        update deployAttempt;

        return DeploymentServices.getDeploymentAttempts(new Set<Id> {deployAttempt.Id})[0];
    }

    static testMethod void attemptModel_codeCoverageValue_no_unit_tests_and_run_tests() {
        setup();

        Integer totalLines = 0;
        Integer totalTests = 0;
        Integer codeCoverage = 0;
        Boolean runTests = true;

        Deployment_Attempt__c deployAttempt = TestingUtils.createDeploymentAttempt(release.Id, instance.Id,
                                                                                 totalLines, totalTests, codeCoverage, runTests);

          List<Deployment_Attempt__c> actualAttempt = DeploymentServices.getDeploymentAttempts(new Set<Id> {deployAttempt.Id});

          Test.startTest();
            DeploymentModel.Attempt actualModel = new DeploymentModel.Attempt(actualAttempt.get(0));
        Test.stopTest();

        String expected = actualModel.NOT_APPLICABLE;
        System.assertEquals(expected, actualModel.codeCoverage, 'Code coverage should be N/A when org has no unit tests and run test option is true');
    }

    static testMethod void attemptModel_codeCoverageValue_no_unit_tests_and_no_run_tests() {
        setup();
        Integer totalLines = 0;
        Integer totalTests = 0;
        Integer codeCoverage = 0;
        Boolean runTests = false;

        Deployment_Attempt__c deployAttempt = TestingUtils.createDeploymentAttempt(release.Id, instance.Id,
                                                                                 totalLines, totalTests, codeCoverage, runTests);

        List<Deployment_Attempt__c> actualAttempt = DeploymentServices.getDeploymentAttempts(new Set<Id> {deployAttempt.Id});

        Test.startTest();
            DeploymentModel.Attempt actualModel = new DeploymentModel.Attempt(actualAttempt.get(0));
        Test.stopTest();

        String expected = actualModel.NOT_APPLICABLE;
        System.assertEquals(expected, actualModel.codeCoverage, 'Code coverage should be N/A when org has no unit tests and run test option is false');
    }

    static testMethod void attemptModel_codeCoverageValue_has_unit_tests_and_no_run_tests() {
        setup();
        Integer totalLines = 0;
        Integer totalTests = 0;
        Integer codeCoverage = 0;
        Boolean runTests = false;

        Deployment_Attempt__c deployAttempt = TestingUtils.createDeploymentAttempt(release.Id, instance.Id,
                                                                                   totalLines, totalTests, codeCoverage, runTests);

        List<Deployment_Attempt__c> actualAttempt = DeploymentServices.getDeploymentAttempts(new Set<Id> {deployAttempt.Id});

        Test.startTest();
          DeploymentModel.Attempt actualModel = new DeploymentModel.Attempt(actualAttempt.get(0));
        Test.stopTest();

        String expected = actualModel.NOT_APPLICABLE;
        System.assertEquals(expected, actualModel.codeCoverage, 'Code coverage should be N/A when org has unit tests and run test option is false');
    }

    static testMethod void attemptModel_codeCoverageValue_has_unit_tests_and_run_tests() {
        setup();
        Integer totalLines = 1;
        Integer totalTests = 1;
        Integer codeCoverage = 75;
        Boolean runTests = true;

        Deployment_Attempt__c deployAttempt = TestingUtils.createDeploymentAttempt(release.Id, instance.Id,
                                                                                   totalLines, totalTests, codeCoverage, runTests);

        List<Deployment_Attempt__c> actualAttempt = DeploymentServices.getDeploymentAttempts(new Set<Id> {deployAttempt.Id});

        Test.startTest();
          DeploymentModel.Attempt actualModel = new DeploymentModel.Attempt(actualAttempt.get(0));
        Test.stopTest();

        String expectedCodeCoverageLabel = codeCoverage + '.00';

        System.assertEquals(expectedCodeCoverageLabel, actualModel.codeCoverage, 'Code coverage should be a percentage number when org has classes and run tests is true');
    }

    static testMethod void attemptModel_apexTestsTotal_no_tests_and_no_run_tests() {
        setup();
        Integer totalLines = 0;
        Integer totalTests = 0;
        Integer codeCoverage = 0;
        Boolean runTests = false;

        Deployment_Attempt__c deployAttempt = TestingUtils.createDeploymentAttempt(release.Id, instance.Id,
                                                                                   totalLines, totalTests, codeCoverage, runTests);

        List<Deployment_Attempt__c> actualAttempt = DeploymentServices.getDeploymentAttempts(new Set<Id> {deployAttempt.Id});

        Test.startTest();
          DeploymentModel.Attempt actualModel = new DeploymentModel.Attempt(actualAttempt.get(0));
        Test.stopTest();

        String expected = '0';
        System.assertEquals(expected, actualModel.apexTestsTotal, 'Unit test value should be 0 when org has no unit tests and run tests is false');
    }

    static testMethod void attemptModel_apexTestsTotal_null() {
        setup();
        Integer totalLines = 0;
        Integer totalTests = null;
        Integer codeCoverage = 0;
        Boolean runTests = true;

        Deployment_Attempt__c deployAttempt = TestingUtils.createDeploymentAttempt(release.Id, instance.Id,
                                                                                   totalLines, totalTests, codeCoverage, runTests);

        List<Deployment_Attempt__c> actualAttempt = DeploymentServices.getDeploymentAttempts(new Set<Id> {deployAttempt.Id});

        Test.startTest();
          DeploymentModel.Attempt actualModel = new DeploymentModel.Attempt(actualAttempt.get(0));
        Test.stopTest();

        String expected = '0';
        System.assertEquals(expected, actualModel.apexTestsTotal, 'Unit test value should be 0 when org null for total unit tests and run tests is true.');
    }

    static testMethod void attemptModel_apexTestsTotal_no_tests_and_run_tests() {
        setup();
        Integer totalLines = 0;
        Integer totalTests = 0;
        Integer codeCoverage = 0;
        Boolean runTests = true;

        Deployment_Attempt__c deployAttempt = TestingUtils.createDeploymentAttempt(release.Id, instance.Id,
                                                                                   totalLines, totalTests, codeCoverage, runTests);

        List<Deployment_Attempt__c> actualAttempt = DeploymentServices.getDeploymentAttempts(new Set<Id> {deployAttempt.Id});
        String expected = totalTests+'';

        Test.startTest();
          DeploymentModel.Attempt actualModel = new DeploymentModel.Attempt(actualAttempt.get(0));
        Test.stopTest();
        System.assertEquals(expected, actualModel.apexTestsTotal, 'Unit test value should be 0 when org has no unit tests and run tests is true');
    }

    static testMethod void attemptModel_apexTestsTotal_has_tests_and_run_tests() {
        setup();
        Integer totalLines = 0;
        Integer totalTests = 1;
        Integer codeCoverage = 0;
        Boolean runTests = true;

        Deployment_Attempt__c deployAttempt = TestingUtils.createDeploymentAttempt(release.Id, instance.Id,
                                                                                   totalLines, totalTests, codeCoverage, runTests);

        List<Deployment_Attempt__c> actualAttempt = DeploymentServices.getDeploymentAttempts(new Set<Id> {deployAttempt.Id});
        String expected = totalTests+'';

        Test.startTest();
          DeploymentModel.Attempt actualModel = new DeploymentModel.Attempt(actualAttempt.get(0));
        Test.stopTest();

        System.assertEquals(expected, actualModel.apexTestsTotal, 'Unit test value should be a number when org has unit tests and run tests is true');
    }

    static testMethod void attemptModel_apexResult_pass() {
        setup();
        String status = 'Success';
        Integer totalLines = 0;
        Integer totalTests = 15;
        Integer codeCoverage = 0;
        Integer numberOfTestErrors = 0;
        Integer numberOfComponentErrors = 0;
        Boolean runTests = true;

        Deployment_Attempt__c deployAttempt = TestingUtils.createDeploymentAttempt(release.Id, instance.Id,
                                                                                   status, totalLines, totalTests,
                                                                                   codeCoverage, runTests, numberOfTestErrors,
                                                                                   numberOfComponentErrors);

        List<Deployment_Attempt__c> actualAttempt = DeploymentServices.getDeploymentAttempts(new Set<Id> {deployAttempt.Id});

        Test.startTest();
          DeploymentModel.Attempt actualModel = new DeploymentModel.Attempt(actualAttempt.get(0));
        Test.stopTest();

        System.assertEquals(actualModel.RESULT_PASS, actualModel.apexResult, 'Apex Result should be pass if the number of test errors is  0');
    }

    static testMethod void attemptModel_apexResult_fail() {
        setup();
        String status = 'Failed';
        Integer totalLines = 0;
        Integer totalTests = 15;
        Integer codeCoverage = 0;
        Integer numberOfTestErrors = 1;
        Integer numberOfComponentErrors = 0;
        Boolean runTests = true;

        Deployment_Attempt__c deployAttempt = TestingUtils.createDeploymentAttempt(release.Id, instance.Id, status, totalLines, totalTests,
                                                                      codeCoverage, runTests, numberOfTestErrors,
                                                                      numberOfComponentErrors);

        List<Deployment_Attempt__c> actualAttempt = DeploymentServices.getDeploymentAttempts(new Set<Id> {deployAttempt.Id});

        Test.startTest();
          DeploymentModel.Attempt actualModel = new DeploymentModel.Attempt(actualAttempt.get(0));
        Test.stopTest();

        System.assertEquals(actualModel.RESULT_FAIL, actualModel.apexResult, 'Apex Result should be fail if the number of test errors is more than 0');
    }

    static testMethod void attemptModel_quickDeploy_showsPriorResults() {
        setup();

        Deployment__c deployment = TestingUtils.createDeployment(release.Id);

        Integer totalLines = 1;
        Integer totalTests = 100;
        Integer codeCoverage = 75;
        Boolean runTests = true;

        Deployment_Attempt__c originalAttempt = TestingUtils.createDeploymentAttempt(release.Id, instance.Id,
                                                                                   totalLines, totalTests, codeCoverage, runTests);

        originalAttempt.Deployment__c = deployment.Id;
        update originalAttempt;

        Deployment_Attempt__c quickDeployAttempt = originalAttempt.clone(false, true);
        quickDeployAttempt.Number_Tests_Total__c = null;
        quickDeployAttempt.Total_Lines__c = null;
        quickDeployAttempt.Total_Code_Coverage__c = null;
        quickDeployAttempt.Run_Tests__c = false;
        quickDeployAttempt.Is_Quick_Deploy__c = true;
        quickDeployAttempt.Is_Validation__c = false;
        insert quickDeployAttempt;

        List<Deployment_Attempt__c> actualAttempt = DeploymentServices.getDeploymentAttempts(new Set<Id> {quickDeployAttempt.Id});

        Test.startTest();
          DeploymentModel.Attempt actualModel = new DeploymentModel.Attempt(actualAttempt.get(0));
        Test.stopTest();

        String expectedCodeCoverageLabel = codeCoverage + '.00';

        System.assertEquals(expectedCodeCoverageLabel, actualModel.codeCoverage, 'Quick deploy results should show original code coverage results');
        System.assertEquals(String.valueOf(totalTests), actualModel.apexTestsTotal, 'Quick deploy results should show original test results');
    }

    static testMethod void attemptModel_apexResult_canceled_componentResultPass() {
        setup();
        String status = 'Canceled';
        Integer totalLines = 0;
        Integer totalTests = 15;
        Integer codeCoverage = 0;
        Integer numberOfTestErrors = 0;
        Integer numberOfComponentErrors = 0;
        Boolean runTests = true;

        Deployment_Attempt__c deployAttempt = TestingUtils.createDeploymentAttempt(release.Id, instance.Id,
                                                                                   status, totalLines, totalTests,
                                                                                   codeCoverage, runTests, numberOfTestErrors,
                                                                                   numberOfComponentErrors);

        List<Deployment_Attempt__c> actualAttempt = DeploymentServices.getDeploymentAttempts(new Set<Id> {deployAttempt.Id});

        Test.startTest();
          DeploymentModel.Attempt actualModel = new DeploymentModel.Attempt(actualAttempt.get(0));
        Test.stopTest();

        System.assertEquals(actualModel.RESULT_CANCELED, actualModel.apexResult, 'Apex Result should be canceled if apex tests total is greater than 0');
        System.assertEquals(actualModel.RESULT_PASS, actualModel.componentResult, 'Component Result should be pass if number of component errors is 0');
    }

    static testMethod void attemptModel_apexResult_canceled_componentResultFail() {
        setup();
        String status = 'Canceled';
        Integer totalLines = 0;
        Integer totalTests = 15;
        Integer codeCoverage = 0;
        Integer numberOfTestErrors = 0;
        Integer numberOfComponentErrors = 1;
        Boolean runTests = true;

        Deployment_Attempt__c deployAttempt = TestingUtils.createDeploymentAttempt(release.Id, instance.Id,
                                                                                   status, totalLines, totalTests,
                                                                                   codeCoverage, runTests, numberOfTestErrors,
                                                                                   numberOfComponentErrors);

        List<Deployment_Attempt__c> actualAttempt = DeploymentServices.getDeploymentAttempts(new Set<Id> {deployAttempt.Id});

        Test.startTest();
          DeploymentModel.Attempt actualModel = new DeploymentModel.Attempt(actualAttempt.get(0));
        Test.stopTest();

        System.assertEquals(actualModel.RESULT_CANCELED, actualModel.apexResult, 'Apex Result should be canceled if apex tests total is greater than 0');
        System.assertEquals(actualModel.RESULT_FAIL, actualModel.componentResult, 'Component Result should be fail if number of component errors is greater than 0');
    }

    static testMethod void attemptModel_componentResult_pass() {
        setup();
        String status = 'Success';
        Integer totalLines = 0;
        Integer totalTests = 0;
        Integer codeCoverage = 0;
        Integer numberOfTestErrors = 0;
        Integer numberOfComponentErrors = 0;
        Boolean runTests = true;

        Deployment_Attempt__c deployAttempt = TestingUtils.createDeploymentAttempt(release.Id, instance.Id,
                                                                                   status, totalLines, totalTests,
                                                                                   codeCoverage, runTests, numberOfTestErrors,
                                                                                   numberOfComponentErrors);

        List<Deployment_Attempt__c> actualAttempt = DeploymentServices.getDeploymentAttempts(new Set<Id> {deployAttempt.Id});

        Test.startTest();
          DeploymentModel.Attempt actualModel = new DeploymentModel.Attempt(actualAttempt.get(0));
        Test.stopTest();

        System.assertEquals(actualModel.RESULT_PASS, actualModel.componentResult, 'Component Result should be pass if number of component errors is 0');
    }

    static testMethod void attemptModel_componentResult_fail() {
        setup();
        String status = 'Failed';
        Integer totalLines = 0;
        Integer totalTests = 0;
        Integer codeCoverage = 0;
        Integer numberOfTestErrors = 0;
        Integer numberOfComponentErrors = 1;
        Boolean runTests = true;

        Deployment_Attempt__c deployAttempt = TestingUtils.createDeploymentAttempt(release.Id, instance.Id,
                                                                                   status, totalLines, totalTests,
                                                                                   codeCoverage, runTests, numberOfTestErrors,
                                                                                   numberOfComponentErrors);

        List<Deployment_Attempt__c> actualAttempt = DeploymentServices.getDeploymentAttempts(new Set<Id> {deployAttempt.Id});

        Test.startTest();
          DeploymentModel.Attempt actualModel = new DeploymentModel.Attempt(actualAttempt.get(0));
        Test.stopTest();

        System.assertEquals(actualModel.RESULT_FAIL, actualModel.componentResult, 'Component Result should be fail if number of component errors is more than 0');
    }

    static testMethod void attemptModel_componentResult_canceled() {
      setup();
        String status = 'Canceled';
        Integer totalLines = 0;
        Integer totalTests = 0;
        Integer codeCoverage = 0;
        Integer numberOfTestErrors = 0;
        Integer numberOfComponentErrors = 0;
        Boolean runTests = true;

        Deployment_Attempt__c deployAttempt = TestingUtils.createDeploymentAttempt(release.Id, instance.Id,
                                                                                   status, totalLines, totalTests,
                                                                                   codeCoverage, runTests, numberOfTestErrors,
                                                                                   numberOfComponentErrors);

        List<Deployment_Attempt__c> actualAttempt = DeploymentServices.getDeploymentAttempts(new Set<Id> {deployAttempt.Id});

        Test.startTest();
          DeploymentModel.Attempt actualModel = new DeploymentModel.Attempt(actualAttempt.get(0));
        Test.stopTest();

        System.assertEquals(actualModel.RESULT_CANCELED, actualModel.componentResult, 'Component Result should be canceled if apex tests have not been run yet');
    }

    static testMethod void isQuickDeployEligible_validationFailure() {
        setup();
        Deployment__c deployment = TestingUtils.createDeployment(release.Id);
        Deployment_Attempt__c attempt = TestingUtils.createDeploymentAttempt(release.Id, instance.Id, DeploymentServices.STATUS_FAILED, 1, 1, 75, true, 0, 0);

        Test.startTest();
            DeploymentModel deploymentModel = new DeploymentModel(deployment, attempt, 0);
        Test.stopTest();

        System.assertEquals(false, deploymentModel.isQuickDeployEligible, 'Deployments that failed should not be eligible for quick deploy');
    }

    static testMethod void isQuickDeployEligible_notValidation() {
        setup();
        Deployment__c deployment = TestingUtils.createDeployment(release.Id);
        Deployment_Attempt__c attempt = TestingUtils.createDeploymentAttempt(release.Id, instance.Id, DeploymentServices.STATUS_SUCCESS, 1, 1, 75, true, 0, 0);
        attempt.Is_Validation__c = false;

        Test.startTest();
            DeploymentModel deploymentModel = new DeploymentModel(deployment, attempt);
        Test.stopTest();

        System.assertEquals(false, deploymentModel.isQuickDeployEligible, 'Deployments that are not validations should not be eligible for quick deploy');
    }

    static testMethod void isQuickDeployEligible_failedCodeCoverage() {
        setup();
        Integer codeCoverage = 74;
        Deployment__c deployment = TestingUtils.createDeployment(release.Id);
        Deployment_Attempt__c attempt = TestingUtils.createDeploymentAttempt(release.Id, instance.Id, DeploymentServices.STATUS_SUCCESS, 1, 1, codeCoverage, true, 0, 0);

        Test.startTest();
            DeploymentModel deploymentModel = new DeploymentModel(deployment, attempt);
        Test.stopTest();

        System.assertEquals(false, deploymentModel.isQuickDeployEligible, 'Deployments with failing code coverage should not be eligible for quick deploy');
    }

    static testMethod void isQuickDeployEligible_withComponentErrors() {
        setup();
        Integer componentErrors = 1;
        Deployment__c deployment = TestingUtils.createDeployment(release.Id);
        Deployment_Attempt__c attempt = TestingUtils.createDeploymentAttempt(release.Id, instance.Id,DeploymentServices.STATUS_SUCCESS, 1, 1, 75, true, 0, componentErrors);

        Test.startTest();
            DeploymentModel deploymentModel = new DeploymentModel(deployment, attempt);
        Test.stopTest();

        System.assertEquals(false, deploymentModel.isQuickDeployEligible, 'Deployments with component errors should not be eligible for quick deploy');
    }

    static testMethod void isQuickDeployEligible_withNoTestsRun() {
        setup();
        Boolean runTests = false;
        Deployment__c deployment = TestingUtils.createDeployment(release.Id);
        Deployment_Attempt__c attempt = TestingUtils.createDeploymentAttempt(release.Id, instance.Id,DeploymentServices.STATUS_SUCCESS, 0, 0, 75, runTests, 0, 0);

        Test.startTest();
            DeploymentModel deploymentModel = new DeploymentModel(deployment, attempt);
        Test.stopTest();

        System.assertEquals(false, deploymentModel.isQuickDeployEligible, 'Deployments that did not run tests should not be eligible for quick deploy');
    }

    static testMethod void isQuickDeployEligible_withTestErrors() {
        setup();
        Integer testErrors = 1;
        Deployment__c deployment = TestingUtils.createDeployment(release.Id);
        Deployment_Attempt__c attempt = TestingUtils.createDeploymentAttempt(release.Id, instance.Id,DeploymentServices.STATUS_SUCCESS, 1, 1, 75, true, testErrors, 0);

        Test.startTest();
            DeploymentModel deploymentModel = new DeploymentModel(deployment, attempt);
        Test.stopTest();

        System.assertEquals(false, deploymentModel.isQuickDeployEligible, 'Deployments with test errors should not be eligible for quick deploy');
    }

    static testMethod void isQuickDeployEligible_oldValidation() {
        setup();
        Deployment__c deployment = TestingUtils.createDeployment(release.Id);
        Deployment_Attempt__c attempt = TestingUtils.createDeploymentAttempt(release.Id, instance.Id,DeploymentServices.STATUS_SUCCESS, 1, 1, 75, true, 0, 0);
        attempt.End_Date__c = Datetime.now().addHours(-(DeploymentModel.QUICK_DEPLOY_MAX_AGE + 1));
        update attempt;

        Test.startTest();
            DeploymentModel deployModel = new DeploymentModel(deployment, attempt);
        Test.stopTest();

        System.assertEquals(false, deployModel.isQuickDeployEligible, 'Deployments that were validated too far in the past should not be eligible for quick deploy');
    }

    static testMethod void isQuickDeployEligible() {
        setup();
        Deployment__c deployment = TestingUtils.createDeployment(release.Id);
        Deployment_Attempt__c attempt = TestingUtils.createDeploymentAttempt(release.Id, instance.Id,DeploymentServices.STATUS_SUCCESS, 1, 1, 75, true, 0, 0);

        Test.startTest();
            DeploymentModel deploymentModel = new DeploymentModel(deployment, attempt);
        Test.stopTest();

        System.assertEquals(true, deploymentModel.isQuickDeployEligible, 'Successful recent validations should be eligible for quick deploy');
    }

    static testMethod void isQuickDeployEligible_withCodeCoverageErrors() {
        setup();
        final Integer codeCoverageErrorCount = 1;
        Deployment__c deployment = TestingUtils.createDeployment(release.Id);
        Deployment_Attempt__c attempt = TestingUtils.createDeploymentAttempt(release.Id, instance.Id,DeploymentServices.STATUS_SUCCESS, 1, 1, 75, true, 0, 0);
        deployment.Deployment_Attempt__c = attempt.Id;
        update deployment;

        Test.startTest();
            DeploymentModel deploymentModel = new DeploymentModel(deployment, attempt, codeCoverageErrorCount);
        Test.stopTest();

        System.assertEquals(false, deploymentModel.isQuickDeployEligible, 'Code coverage errors does not make quick deploy eligible.');
    }

    static testMethod void getIsSuccess_false() {
        setup();
        Deployment__c deployment = TestingUtils.createDeployment(release.Id);
        deployment.Build__r = new Build__c(Status__c = DeploymentModel.FAILED_BUILD_STATUS);

        Test.startTest();
            DeploymentModel dModel = new DeploymentModel(deployment, null, 0);
        Test.stopTest();

        System.assertEquals(false, dModel.isSuccess, 'This deployment should not be successful with zero build errors and a build status of failed.');
    }
}