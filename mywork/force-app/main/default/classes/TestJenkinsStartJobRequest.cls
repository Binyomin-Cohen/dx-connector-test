@isTest
private class TestJenkinsStartJobRequest {

	private static Auth_User__c authUser;
	private static Build__c build;
	private static Instances__c instance;
	private static Jenkins_Build__c jenkinsBuild;
	private static Jenkins_Job__c jenkinsJob;
	private static Release__c release;
	private static Jenkins_Config__c jenkinsConfig;
	private static ALM_Private__c sightlineSettings;

	static void setup() {
		System.runAs(TestingUtils.ADMIN_USER) {
			release = new Release__c(Name='Jenkins Release');
			insert release;

			instance = new Instances__c(Name='Jenks-Instance', Is_ALM_Instance__c=true);
			insert instance;

			jenkinsJob = TestingUtils.createJenkinsJob(instance.Id, release.Id);
			jenkinsBuild = TestingUtils.createJenkinsBuild(jenkinsJob.Id);

			build = TestingUtils.buildBuild(release.Id, jenkinsBuild.Id);
			insert build;
			// Setting isForTools to true because that's OAuthService.getSightlineUser() returns the auth user of the sightline Instance, which is isForTools === true
			authUser = TestingUtils.createAuthUser(UserInfo.getUserId(), instance.Id, true);
			authUser.Refresh_Token__c = 'jenks-refresh-token-123';
			update authUser;

			sightlineSettings = TestingUtils.createOAuthSettings();
			setupJenkinsConfig();
		}
	}

	static void setupJenkinsConfig() {
		jenkinsConfig = new Jenkins_Config__c(
				Endpoint__c = 'TEST_ENDPOINT',
				User_ID__c = 'TEST_USER_ID',
				User_API_Token__c = 'TEST_USER_API_TOKEN'
		);
		insert jenkinsConfig;
	}

	static testMethod void jenkinsStartJobRequest_constructor() {
		setup();

		Test.startTest();
			JenkinsStartJobRequest jenkinsJobRequest = new JenkinsStartJobRequest(
					jenkinsBuild.Name, jenkinsBuild.Jenkins_Job__r.Token__c, jenkinsBuild.Jenkins_Job__r.Path__c,
					build.Package_Url__c);
		Test.stopTest();

		System.assertEquals(jenkinsBuild.Name, jenkinsJobRequest.jenkinsBuildName,
				'The Jenkins Build Name should match');
		System.assertEquals(build.Package_Url__c, jenkinsJobRequest.buildPackageUrl,
				'The build package url should be correct');
		System.assertEquals(jenkinsConfig.Endpoint__c + jenkinsBuild.Jenkins_Job__r.Path__c, jenkinsJobRequest.jenkinsEndpoint,
				'The jenkins config endpoint should be correct');
		System.assertEquals(jenkinsConfig.User_API_Token__c, jenkinsJobRequest.jenkinsUserApiToken,
				'The jenkins config user API token should be correct');
		System.assertEquals(jenkinsConfig.User_ID__c, jenkinsJobRequest.jenkinsUserId,
				'The jenkins config user Id should be correct');
		System.assertEquals(jenkinsBuild.Jenkins_Job__r.Token__c, jenkinsJobRequest.jenkinsJobTokenParam,
				'The jenkins auth token should be correct');

		// BaseRequest fields
		System.assert(!String.isBlank(jenkinsJobRequest.sightlineServerURL),
				'The Sightline Server Url should be populated');
		System.assert(!String.isBlank(jenkinsJobRequest.organizationId),
				'The Sightline Organization Id should be populated');
		System.assertEquals(sightlineSettings.Consumer_Key__c, jenkinsJobRequest.clientId,
				'The client Id should be correct');
		System.assertEquals(sightlineSettings.Consumer_Secret__c, jenkinsJobRequest.clientSecret,
				'The client secret should be correct');
		System.assertEquals(authUser.Refresh_Token__c, jenkinsJobRequest.sightlineRefreshToken,
				'The sightlineRefreshToken should be correct');
	}
}
