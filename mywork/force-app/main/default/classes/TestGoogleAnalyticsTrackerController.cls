@isTest
private with sharing class TestGoogleAnalyticsTrackerController {

    static testMethod void constructor_copiesParams() {
        final String APP_NAME = 'myApp';
        final String PAGE_TITLE = 'slingshot';

        PageReference currentPage = new PageReference('/apex/GAEvent?pageTitle=' + PAGE_TITLE + '&appName=' + APP_NAME);
        Test.setCurrentPage(currentPage);

        Test.startTest();
            GoogleAnalyticsTrackerController controller = new GoogleAnalyticsTrackerController();
        Test.stopTest();

        System.assertEquals(APP_NAME, controller.appName, 'The app name should be copied from the query string');
        System.assertEquals(PAGE_TITLE, controller.pageTitle, 'The page title should be copied from the query string');
    }
}