@isTest
public class TestALMRestServices {
    @isTest
    private static void makeSensitiveHTTPRequest_sanitaryErrorMessage_default_nullMap() {
        String serverErrorMessage = 'Test Server Error Message';
        String uiErrorMessage = 'Test UI Error Message';

        Test.setMock(HttpCalloutMock.class, new MockSimpleResponse(ALMRestServices.HTTP_INTERNAL_SERVER_ERROR, serverErrorMessage));

        Test.startTest();

            try {
                ALMRestServices.makeSensitiveHTTPRequest(ALMRestServices.RequestMethod.POST, ALMRestServices.WEB_SERVICE_URL, null, null, null, null);
                System.assert(false, 'An exception should be thrown.');
            } catch (Exception e) {
                System.assertEquals(System.Label.HTTP_Error, e.getMessage(), 'The properly sanitized default UI error message should be returned.');
            }

        Test.stopTest();
    }

    @isTest
    private static void makeSensitiveHTTPRequest_sanitaryErrorMessage_default_emptyMap() {
        String serverErrorMessage = 'Test Server Error Message';
        String uiErrorMessage = 'Test UI Error Message';
        Map<String, String> errorSubstitutionsMap = new Map<String, String>();

        Test.setMock(HttpCalloutMock.class, new MockSimpleResponse(ALMRestServices.HTTP_INTERNAL_SERVER_ERROR, serverErrorMessage));

        Test.startTest();

            try {
                ALMRestServices.makeSensitiveHTTPRequest(ALMRestServices.RequestMethod.POST, ALMRestServices.WEB_SERVICE_URL, null, null, null, errorSubstitutionsMap);
                System.assert(false, 'An exception should be thrown.');
            } catch (Exception e) {
                System.assertEquals(System.Label.HTTP_Error, e.getMessage(), 'The properly sanitized default UI error message should be returned.');
            }

        Test.stopTest();
    }

    @isTest
    private static void makeSensitiveHTTPRequest_sanitaryErrorMessage_default_noMatch() {
        String serverErrorMessage = 'Test Server Error Message';
        String uiErrorMessage = 'Test UI Error Message';
        Map<String, String> errorSubstitutionsMap = new Map<String, String>{
            serverErrorMessage => uiErrorMessage
        };

        Test.setMock(HttpCalloutMock.class, new MockSimpleResponse(ALMRestServices.HTTP_INTERNAL_SERVER_ERROR, 'Unsanitary Server Error Message'));

        Test.startTest();

            try {
                ALMRestServices.makeSensitiveHTTPRequest(ALMRestServices.RequestMethod.POST, ALMRestServices.WEB_SERVICE_URL, null, null, null, errorSubstitutionsMap);
                System.assert(false, 'An exception should be thrown.');
            } catch (Exception e) {
                System.assertEquals(System.Label.HTTP_Error, e.getMessage(), 'The properly sanitized default UI error message should be returned.');
            }

        Test.stopTest();
    }

    @isTest
    private static void makeSensitiveHTTPRequest_sanitaryErrorMessage_custom() {
        String serverErrorMessage = 'Test Server Error Message';
        String uiErrorMessage = 'Test UI Error Message';
        Map<String, String> errorSubstitutionsMap = new Map<String, String>{
            serverErrorMessage => uiErrorMessage
        };

        Test.setMock(HttpCalloutMock.class, new MockSimpleResponse(ALMRestServices.HTTP_INTERNAL_SERVER_ERROR, serverErrorMessage));

        Test.startTest();

            try {
                ALMRestServices.makeSensitiveHTTPRequest(ALMRestServices.RequestMethod.POST, ALMRestServices.WEB_SERVICE_URL, null, null, null, errorSubstitutionsMap);
                System.assert(false, 'An exception should be thrown.');
            } catch (Exception e) {
                System.assertEquals(uiErrorMessage, e.getMessage(), 'The properly sanitized custom UI error message should be returned.');
            }

        Test.stopTest();
    }
}