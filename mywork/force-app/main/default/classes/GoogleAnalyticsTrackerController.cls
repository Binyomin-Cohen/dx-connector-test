public with sharing class GoogleAnalyticsTrackerController {

    public String pageTitle {get; set;}
    public String appName {get; set;}

    public GoogleAnalyticsTrackerController() {
        Map<String, String> params = ApexPages.currentPage().getParameters();
        
        pageTitle = params.get('pageTitle');
        appName = params.get('appName');
        
    }

    @AuraEnabled
    public static String getVisualforceDomain() {
        return InstanceServices.getVisualforceDomain(URL.getCurrentRequestUrl().toExternalForm());
    }

}