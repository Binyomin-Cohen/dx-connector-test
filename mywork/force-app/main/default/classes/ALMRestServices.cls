public with sharing class ALMRestServices {
    public enum RequestMethod {
        GET,
        POST
    }

    public static final Integer HTTP_OK = 200;
    public static final Integer HTTP_CREATED = 201;
    public static final Set<Integer> HTTP_STATUSES_SUCCESS = new Set<Integer>{
        HTTP_OK,
        HTTP_CREATED
    };

    public static final Integer HTTP_BAD_REQUEST = 400;
    public static final Integer HTTP_UNAUTHORIZED = 401;
    public static final Integer HTTP_FORBIDDEN = 403;
    public static final Integer HTTP_NOT_FOUND = 404;
    public static final Set<Integer> HTTP_STATUSES_CLIENT_ERROR = new Set<Integer>{
        HTTP_BAD_REQUEST,
        HTTP_UNAUTHORIZED,
        HTTP_FORBIDDEN,
        HTTP_NOT_FOUND
    };

    public static final Integer HTTP_INTERNAL_SERVER_ERROR = 500;
    public static final Set<Integer> HTTP_STATUSES_SERVER_ERROR = new Set<Integer>{
        HTTP_INTERNAL_SERVER_ERROR
    };

    public static final Map<Integer, String> HTTP_CODES_TO_STATUSES = new Map<Integer, String>{
        HTTP_OK => 'OK',
        HTTP_CREATED => 'Created',
        HTTP_BAD_REQUEST => 'Bad Request',
        HTTP_UNAUTHORIZED => 'Unauthorized',
        HTTP_FORBIDDEN => 'Forbidden',
        HTTP_NOT_FOUND => 'Not Found',
        HTTP_INTERNAL_SERVER_ERROR => 'Internal Server Error'
    };

    public static final String DEFAULT_WEB_SERVICE_URL = 'https://tools.bluewolf.com';
    public static String WEB_SERVICE_URL {

        get {
            if (WEB_SERVICE_URL == null) {
                if (String.isBlank(ALMSettings__c.getOrgDefaults().Web_Service_Domain__c)) {
                    WEB_SERVICE_URL = DEFAULT_WEB_SERVICE_URL;
                } else {
                    WEB_SERVICE_URL = ALMSettings__c.getOrgDefaults().Web_Service_Domain__c;
                }
            }

            return WEB_SERVICE_URL;
        }
    }

    public static final Integer DEFAULT_TIMEOUT = 30 * 1000;

    /**
    * @throws ALMException
    */
    public static String makeGetRequest(String endpoint) {
        return makeGetRequest(endpoint, new Map<String, String>());
    }

    /**
    * @throws ALMException
    */
    public static String makeGetRequest(String endpoint, String sessionId) {
        Map<String, String> headerMap = new Map<String, String>();
        headerMap.put('Authorization', 'Bearer ' + sessionId);

        return makeGetRequest(endpoint, headerMap);
    }

    /**
    * @throws ALMException
    */
    public static String makeGetRequest(String endpoint, Map<String, String> headerMap) {
        return makeHTTPRequest(RequestMethod.GET, endpoint, headerMap, null, null);
    }

    /**
    * @throws ALMException
    */
    public static String makePostRequest(String endpoint, String body) {
        Map<String, String> headerMap = new Map<String, String>();
        headerMap.put('Content-Type', 'application/json');

        return makePostRequest(endpoint, body, headerMap);
    }

    /**
    * @throws ALMException
    */
    public static String makePostRequest(String endpoint, String body, String sessionId) {
        Map<String, String> headerMap = new Map<String, String>();
        headerMap.put('Content-Type', 'application/json');
        headerMap.put('Authorization', 'Bearer ' + sessionId);

        return makePostRequest(endpoint, body, headerMap);
    }

    /**
    * @throws ALMException
    */
    public static String makePostRequest(String endpoint, String body, Map<String, String> headerMap) {
        return makeHTTPRequest(RequestMethod.POST, endpoint, headerMap, body, null);
    }

    /**
    * @throws ALMException
    */
    public static String makePostRequestWithBlob(String endpoint, Blob body, Map<String, String> headerMap) {
        return makeHTTPRequest(RequestMethod.POST, endpoint, headerMap, null, body);
    }

    /**
    * Makes a silent HTTP request which produces no debug output and does not allow dynamic exception messages to be thrown.
    * @param method - The type of HTTP request to be made (e.g. GET, POST, etc.).
    * @param endpoint - The endpoint to which the HTTP request should be made.
    * @param headerMap - A map containing header key/value pairs for the HTTP request header.
    * @param body - The string body for the HTTP request.
    * @param optionsMap - A map containing miscellaneous options for making the HTTP request.
    * @param errorMessageSubstitutionsMap - A map containing various error message substitutions for sanitizing sensitive error messages.
    * @return - The string body of the HTTP response.
    * @throws ALMException
    */
    public static String makeSensitiveHTTPRequest(RequestMethod method, String endpoint, Map<String, String> headerMap, String body, Map<String, Object> optionsMap) {
        return makeSensitiveHTTPRequest(method, endpoint, headerMap, body, optionsMap, null);
    }

    /**
    * Makes a silent HTTP request which produces no debug output and does not allow dynamic exception messages to be thrown.
    * @param method - The type of HTTP request to be made (e.g. GET, POST, etc.).
    * @param endpoint - The endpoint to which the HTTP request should be made.
    * @param headerMap - A map containing header key/value pairs for the HTTP request header.
    * @param body - The string body for the HTTP request.
    * @param optionsMap - A map containing miscellaneous options for making the HTTP request.
    * @return - The string body of the HTTP response.
    * @throws ALMException
    */
    public static String makeSensitiveHTTPRequest(RequestMethod method, String endpoint, Map<String, String> headerMap, String body, Map<String, Object> optionsMap, Map<String, String> errorMessageSubstitutionsMap) {
        try {
            if (headerMap == null) {
                headerMap = new Map<String, String>();
                headerMap.put('Content-Type', 'application/json');
            }
            headerMap.put('Cache-Control', 'no-store');

            if (optionsMap == null) {
                optionsMap = new Map<String, Object>();
            }
            optionsMap.put('allowDebug', false);

            return makeHTTPRequest(method, endpoint, headerMap, body, null, optionsMap);
        } catch (Exception e) {
            String sanitaryErrorMessage = System.Label.HTTP_Error;

            if (errorMessageSubstitutionsMap != null) {
                for (String errorMessage : errorMessageSubstitutionsMap.keySet()) {
                    if (e.getMessage().contains(errorMessage)) {
                        sanitaryErrorMessage = errorMessageSubstitutionsMap.get(errorMessage);
                    }
                }
            }

            throw new ALMException(sanitaryErrorMessage);
        }
    }

    private static String makeHTTPRequest(RequestMethod method, String endpoint, Map<String, String> headerMap, String bodyString, Blob bodyBlob) {
        Map<String, Object> optionsMap = new Map<String, Object>();
        optionsMap.put('allowDebug', true);

        return makeHTTPRequest(method, endpoint, headerMap, bodyString, bodyBlob, optionsMap);
    }

    private static String makeHTTPRequest(RequestMethod method, String endpoint, Map<String, String> headerMap, String bodyString, Blob bodyBlob, Map<String, Object> optionsMap) {
        if (method == null || String.isBlank(endpoint)) {
            throw new ALMException(System.Label.HTTP_Invalid_Request);
        }

        Integer timeout = DEFAULT_TIMEOUT;
        Boolean allowDebug = false;
        if (optionsMap != null) {
            if (optionsMap.get('timeout') != null) {
                timeout = (Integer)optionsMap.get('timeout');
            }
            if (optionsMap.get('allowDebug') != null) {
                allowDebug = (Boolean)optionsMap.get('allowDebug');
            }
        }

        HttpRequest request = new HttpRequest();
        request.setEndpoint(endpoint);
        request.setTimeout(timeout);

        if (method == RequestMethod.GET) {
            request.setMethod('GET');
        } else if (method == RequestMethod.POST) {
            request.setMethod('POST');

            if (!String.isBlank(bodyString)) {
                request.setBody(bodyString);

                if (allowDebug) {
                    System.debug('HTTP REQUEST BODY:\n' + bodyString);
                }
            } else if (bodyBlob != null) {
                request.setBodyAsBlob(bodyBlob);

                if (allowDebug) {
                    System.debug('HTTP REQUEST BODY BLOB:\n' + bodyBlob.toString());
                }
            }
        } else {
            throw new ALMException(System.Label.HTTP_Invalid_Request);
        }

        if (headerMap != null) {
            for (String header : headerMap.keySet()) {
                if (!String.isBlank(header) && !String.isBlank(headerMap.get(header))) {
                    request.setHeader(header, headerMap.get(header));
                }
            }
        }

        HttpResponse response;
        try {
            response = new Http().send(request);

            if (String.isBlank(response.getStatus()) || response.getStatusCode() == null || response.getBody() == null) {
                throw new ALMException(System.Label.Generic_Error);
            } else if (!HTTP_STATUSES_SUCCESS.contains(response.getStatusCode())) {
                String responseError =
                    'HTTP ' + response.getStatusCode() + ' (' + response.getStatus() + '): ' + response.getBody();


                if (allowDebug) {
                    System.debug(System.LoggingLevel.ERROR, responseError);
                }

                //TODO: use label
                throw new ALMException(responseError);
            }
        } catch (System.CalloutException e) {
            throw new ALMException(e.getMessage());
        }

        return response.getBody();
    }
}