@isTest
global class MockOAuthAPI implements HttpCalloutMock{

    public static final String SUCCESS_ACCESS_TOKEN_REQUEST = 'access token success';
    public static final String FAILURE_ACCESS_TOKEN_REQUEST = 'access token failure';
    public static final String SUCCESS_ACCESS_TOKEN = '00Dd0000000fH0n!AQMAQKhRXCOo1OrhIHnfFxoEGHjl2EpJuX1Ar3mmX8yec57MKtyD.ezkRl6KQEfZ.I__Pk_LvQpb4_tt1Vl.XBQ8dyGCEh6n';
    private Map<String, HttpCalloutMock> requests;

    public Boolean hasAnotherRefreshRequestBeenCalled = false;

    private String action;
    @testVisible
    private Integer statusCode;
    @testVisible
    private Integer refreshStatusCode;

    private String userInfoResponseBody;
    private String refreshResponseBody;

    public MockOAuthAPI(String action) {
        this(action, action == FAILURE_ACCESS_TOKEN_REQUEST ? OAuthRequest.ERROR_FORBIDDEN_STATUS_CODE : OAuthRequest.SUCCESS_STATUS_CODE);
    }

    public MockOAuthAPI(String action, Integer statusCode) {
        this.action = action;
        this.statusCode = statusCode;
        this.refreshStatusCode = statusCode;
    }

    public MockOAuthAPI(String action, Integer statusCode, String userInfoResponseBody) {
        this(action, statusCode);
        this.userInfoResponseBody = userInfoResponseBody;
    }

    public MockOAuthAPI(String action, Integer statusCode, Integer refreshStatusCode, String userInfoResponseBody, String refreshResponseBody) {
        this.action = action;
        this.statusCode = statusCode;
        this.refreshStatusCode = refreshStatusCode == null ? statusCode : refreshStatusCode;

        this.userInfoResponseBody = userInfoResponseBody;
        this.refreshResponseBody = refreshResponseBody;
    }


	public MockOAuthAPI(Map<String, HttpCalloutMock> requests) {
		this.requests = requests;
	}

	public void addRequestMock(String url, HttpCalloutMock mock) {
		requests.put(url, mock);
	}

    global HttpResponse respond(HttpRequest request) {
        if(requests != null && !requests.isEmpty()) {
            HttpCalloutMock mock = requests.get(request.getEndpoint());
            if (mock != null) {
                return mock.respond(request);
            } else {
                throw new ALMException('HTTP callout not supported for test methods : request Endpoint -> ' + request.getEndpoint());
            }
        } else {
            Boolean isTokenRequest = request.getEndpoint().contains(OAuthRequest.OAUTH_TOKEN_URL) && request.getMethod() == 'POST';

            if(isTokenRequest && this.hasAnotherRefreshRequestBeenCalled != true)
            {
                this.hasAnotherRefreshRequestBeenCalled = true;
            }

            HttpResponse response = new HttpResponse();

            response.setStatusCode(this.statusCode);
            if (this.hasAnotherRefreshRequestBeenCalled == true) {
                response.setStatusCode(this.refreshStatusCode);
            }

            response.setHeader('Content-Type', 'application/json');


            if (!isTokenRequest){
                if (!hasAnotherRefreshRequestBeenCalled && this.userInfoResponseBody != null){ // First call
                    response.setBody(this.userInfoResponseBody);
                } else if (hasAnotherRefreshRequestBeenCalled && this.refreshResponseBody != null){ // Second call
                    response.setBody(this.refreshResponseBody);
                }
            }

            // Defaults
            if (String.isBlank(response.getBody())){
                if (action == SUCCESS_ACCESS_TOKEN_REQUEST){
                    response.setBody(
                        '{ "id":"https://login.salesforce.com/id/00Dd0000000fH0nEAE/005d00000014TvdAAE", ' +
                        '"issued_at":"1427824244958", ' +
                        '"scope":"id full custom_permissions api openid visualforce web refresh_token chatter_api", ' +
                        '"instance_url":"https://talis-dev-ed.my.salesforce.com", ' +
                        '"token_type":"Bearer", ' +
                        '"refresh_token":"5Aep861.EkZJuT7_luRTKa1lRkM0c2r.DgfdbWjCsCLDwCQY67uAKnzuG5LfFJCyyf2h08qmBMaKTV9sKsfZodL", ' +
                        '"id_token":"eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCIsImtpZCI6IjE5NCJ9.eyJleHAiOjE0Mjc4MjQzNjQsInN1YiI6Imh0dHBzOi8vbG9naW4uc2FsZXNmb3JjZS5jb20vaWQvMDBEZDAwMDAwMDBmSDBuRUFFLzAwNWQwMDAwMDAxNFR2ZEFBRSIsImF0X2hhc2giOiI2b0JHd2JPZklJUEdyclhhWWFIUm5BIiwiYXVkIjoiM01WRzl4T0NYcTRJRDF1R194MU1Qd3RGV1V2d0VKdm5kY1QuRWwycFprZWNVTVdsSlhhazNFQzNEbTdDeE5RRUxoQmpWaldxM2xyNDhmdmdwaTdqeCIsImlzcyI6Imh0dHBzOi8vbG9naW4uc2FsZXNmb3JjZS5jb20iLCJpYXQiOjE0Mjc4MjQyNDR9.Pq1Y7qrpfGCSYK-DpWxL7spEhmfX5seACT9RdNn4kVoZxkPV9rxhpnZ7wWatdWFTXNjGvg-n4v4hTv2WxuUHOrXOShgZRIr-csSlzSM1CHx__AHZOYHr_laVbmywzmdmM-hV9X4mbVzfqJcmWpflOtBEBKAGZn_WzU0YOR3EsnHAMKk6iV0YmbeVp70U3UOtJhgqasfJ6cT0fD20ApB1FOnI6CwoAsrKCqNCRa-VfQJEWCUAQ005XUHdneu3ZRxf6x8NqO76FO54398fha7zUmCum7dMNLFIrol848Md9vpB5XEiJuD3FI2ibHSsansZhwPDlubNJEkJhEXnKIAVwlI6gWBYgKwsaMvzGvDbdFy-ZMD5In2T_YmjsldoekzGtWIgSBgi3Q4n4Ej5qf4JeQS1osr-4gW7pYhSj2G2Uh5m-cx1UybowYlWSSEhHgnQcGJ2bcTgbTmTtTO1XJSOdSFAvoj3lB2iADWXnraHum-1kmHBu4Jh46JB65Ll5FHPTHkwBFk0ssOeTM6a4AQumr5gIiJijurBjKeCLwJ6ZDvlGYLuuXKZa8Z1tV4u3rdKovK-SX89hJka69XqHU9FpIJgYEV7pP0lliBFZdwMTrRBpLoWACQohi0a7UxxyXg9MlTupB1FWD_urRHvbAz91w-gMd2Rs5QHmlyoq5HELQU", ' +
                        '"signature":"013h68shBXdHtxNxMnXYxfk+VLTC5lrmN13HnlyWcIM=", ' +
                        '"access_token":"'+SUCCESS_ACCESS_TOKEN+'" }'
                    );
                } else if (action == FAILURE_ACCESS_TOKEN_REQUEST){
                    response.setBody(
                        '{ "error":"invalid_grant", ' +
                        '"error_description":"invalid authorization code" }'
                    );
                }
            }
            return response;
        }


    }

}