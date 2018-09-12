public with sharing class JenkinsStartJobRequest extends BaseRequest {

	public String buildPackageUrl;
	public String jenkinsBuildName;
	public String jenkinsEndpoint;
	public String jenkinsUserApiToken;
	public String jenkinsUserId;
	public String jenkinsJobTokenParam;

	public JenkinsStartJobRequest(String jenkinsBuildName, String jenkinsJobTokenParam, String jenkinsPath,
	                              String buildPackageUrl) {
		super();

		Jenkins_Config__c jenkinsConfig = Jenkins_Config__c.getInstance();
		if (jenkinsConfig == null || String.isBlank(jenkinsConfig.Endpoint__c)) {
			throw new ALMException(JenkinsServices.CONFIG_ERROR);
		}

		this.jenkinsBuildName = jenkinsBuildName;
		this.buildPackageUrl = buildPackageUrl;
		this.jenkinsEndpoint = jenkinsConfig.Endpoint__c + jenkinsPath;
		this.jenkinsUserApiToken = jenkinsConfig.User_API_Token__c;
		this.jenkinsUserId = jenkinsConfig.User_ID__c;
		this.jenkinsJobTokenParam = jenkinsJobTokenParam;
	}
}
