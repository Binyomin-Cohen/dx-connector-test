public with sharing class ParseBuildPackageRequest extends BaseRequest {

    public String buildId;
    public String buildPackageUrl;

    public ParseBuildPackageRequest(String buildId, String buildPackageUrl) {
        super();

        this.buildId = buildId;
        this.buildPackageUrl = buildPackageUrl;
    }
}