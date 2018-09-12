@isTest
private class TestFeedbackRestService
{
    static Feedback_API_Settings__c apiSettings;

    static void setup()
    {
        apiSettings = TestingUtils.createFeedackAPISettings();
        createFeedbackMapping();
    }

    static testMethod void create_failure_settingsNotDefined()
    {
        Backlog__c backlogData = new Backlog__c();

        String feedbackData = JSON.serialize( backlogData );

        Test.startTest();

            FeedbackRestService.Response response = FeedbackRestService.create(feedbackData, '');

        Test.stopTest();

        System.assertEquals(false, response.success, 'The request should fail when there are no settings.');
        System.assertEquals(FeedbackRestService.NO_SETTINGS_ERROR_MSG, response.message, 'The request should fail when there are no settings.');
    }

    static testMethod void create_failure_invalidSettings()
    {
        apiSettings = TestingUtils.createFeedackAPISettings();
        apiSettings.Target_Object_Name__c = 'InvalidObjectName';
        System.runAs( TestingUtils.ADMIN_USER ) {
            update apiSettings;
        }
        createFeedbackMapping();

        Backlog__c backlogData = new Backlog__c();

        String feedbackData = JSON.serialize( backlogData );

        Test.startTest();

            FeedbackRestService.Response response = FeedbackRestService.create(feedbackData, apiSettings.Org_Id__c);

        Test.stopTest();

        System.assertEquals(false, response.success, 'The request should fail when there are invalid settings.');
        System.assertEquals(FeedbackRestService.INVALID_SETTINGS_ERROR_MSG, response.message, 'The request should fail when there are invalid settings.');
    }

    static testMethod void create_failure_invalidMapping()
    {
        setup();

        TestingUtils.createFeedackAPIMapping( SObjectServices.getFullyQualifiedName('Blocked__c'), 'bad_field');

        Backlog__c backlogData = new Backlog__c(Blocked__c=false);

        String feedbackData = JSON.serialize( backlogData );

        Test.startTest();

            FeedbackRestService.Response response = FeedbackRestService.create(feedbackData, apiSettings.Org_Id__c);

        Test.stopTest();

        System.assertEquals(false, response.success, 'The request should fail when there is an invalid mapping.');
        System.assert( response.message.contains( FeedbackRestService.INVALID_MAPPING_ERROR_MSG) , 'The request should fail when there is an invalid mapping');
    }

    static testMethod void create_failure_invalidJSON()
    {
        setup();
        String feedbackData = '{"key" : val[1]';

        Test.startTest();

            FeedbackRestService.Response response = FeedbackRestService.create(feedbackData, apiSettings.Org_Id__c);

        Test.stopTest();

        System.assertEquals(false, response.success, 'The request should fail when there are no settings.');
        System.assertEquals(FeedbackRestService.INVALID_JSON_ERROR, response.message, 'The request should fail when there is invalid JSON.');
    }

    static testMethod void create_failure_unauthorized()
    {
        setup();

        Backlog__c backlogData = new Backlog__c(Blocked__c=false);
        String feedbackData = JSON.serialize( backlogData );

        Test.startTest();

            FeedbackRestService.Response response = FeedbackRestService.create(feedbackData, '');

        Test.stopTest();

        System.assertEquals(false, response.success, 'The request should fail when there is no org id set.');
        System.assertEquals(FeedbackRestService.UNAUTHORIZED_MSG, response.message, 'The request should fail when the user is not authorized.');
    }

    static testMethod void create_backlogWithData_success()
    {
        setup();

        Backlog__c backlogData = new Backlog__c();
        backlogData.Business_Value__c = 8;
        backlogData.Description__c = 'A description with text';

        String feedbackData = JSON.serialize( backlogData );

        Test.startTest();

           FeedbackRestService.Response response = FeedbackRestService.create(feedbackData, apiSettings.Org_Id__c);

        Test.stopTest();

        System.assert(response.success, 'The request should be successful:' + response.message);

        List<Backlog__c> backlogs = [ SELECT Id, Name, Business_Value__c, Solution__c FROM Backlog__c ];

        System.assertEquals( 1, backlogs.size(), 'One backlog record should have been created');

        Backlog__c createdBacklog = backlogs[0];
        System.assertEquals( createdBacklog.Id, response.createdId, 'The response Id should be set');
        System.assertEquals( createdBacklog.Name, response.createdName, 'The created record Name should be set in the reponse');

        System.assertEquals( backlogData.Business_Value__c, createdBacklog.Business_Value__c, 'Fields on the backlog should be mapped using the feedback mapping');
        System.assertEquals( backlogData.Description__c, createdBacklog.Solution__c, 'Fields on the backlog should be mapped using the feedback mapping');
    }

/*
    Removing test for now since we have no Date fields in the PM package
    static testMethod void create_backlogWithData_mapDate()
    {
        Feedback_API_Settings__c settings = new Feedback_API_Settings__c();
        settings.Org_Id__c = '123456789';
        settings.Target_Object_Name__c = SObjectServices.getFullyQualifiedName( 'Test_Case__c' );

        System.runAs( TestingUtils.ADMIN_USER ) {
            insert settings;
        }

        Feedback_API_Mapping__c dateMapping = TestingUtils.createFeedackAPIMapping(SObjectServices.getFullyQualifiedName('End_Date__c'), SObjectServices.getFullyQualifiedName('End_Date__c'));

        Test_Case__c backlogData = new Test_Case__c();
        backlogData.End_Date__c = Date.today();

        String feedbackData = JSON.serialize( backlogData );

        Test.startTest();

           FeedbackRestService.Response response = FeedbackRestService.create(feedbackData, settings.Org_Id__c);

        Test.stopTest();

        System.assert(response.success, 'The request should be successful:' + response.message);
    }
*/
    static testMethod void create_backlogWithData_mapDateTime()
    {
        setup();

        Feedback_API_Mapping__c datetimeMapping = TestingUtils.createFeedackAPIMapping(SObjectServices.getFullyQualifiedName('Closed_Date__c'), SObjectServices.getFullyQualifiedName('Closed_Date__c'));

        Backlog__c backlogData = new Backlog__c();
        backlogData.Closed_Date__c = Datetime.now();

        String feedbackData = JSON.serialize( backlogData );

        Test.startTest();

           FeedbackRestService.Response response = FeedbackRestService.create(feedbackData, apiSettings.Org_Id__c);

        Test.stopTest();

        System.assert(response.success, 'The request should be successful:' + response.message);

        List<Backlog__c> backlogs = [ SELECT Id, Name, Business_Value__c, Solution__c, Closed_Date__c FROM Backlog__c ];

        System.assertEquals( 1, backlogs.size(), 'One backlog record should have been created');

        Backlog__c createdBacklog = backlogs[0];
        System.assertEquals( createdBacklog.Id, response.createdId, 'The response Id should be set');

        System.assertEquals( backlogData.Closed_Date__c, createdBacklog.Closed_Date__c, 'Datetime Fields on the backlog should be mapped using the feedback mapping');
    }

    static testMethod void create_backlogWithComplexMapping_conditional()
    {
        final String DEFECT_STATUS = 'Bug';
        setup();

        Feedback_API_Mapping__c complexMapping1 = TestingUtils.createFeedackAPIMapping(SObjectServices.getFullyQualifiedName('Status__c'), 'RecordTypeId');
        complexMapping1.Is_Complex__c = true;
        complexMapping1.Operator__c = FeedbackRestService.EQUALS_OPERATOR;
        complexMapping1.Comparison_Value__c = DEFECT_STATUS;
        complexMapping1.Target_Value__c = [SELECT Id FROM RecordType WHERE SObjectType = :SObjectServices.getFullyQualifiedName('Backlog__c') AND Name = 'Defect'].Id;

        Feedback_API_Mapping__c complexMapping2 = TestingUtils.createFeedackAPIMapping(SObjectServices.getFullyQualifiedName('Summary__c'), SObjectServices.getFullyQualifiedName('Description__c'));
        complexMapping2.Is_Complex__c = true;
        complexMapping2.Operator__c = FeedbackRestService.EQUALS_OPERATOR;
        complexMapping2.Comparison_Value__c = 'Not a bug';
        complexMapping2.Target_Value__c = 'Some value';
        System.runAs( TestingUtils.ADMIN_USER ) {
           update new List<Feedback_API_Mapping__c>{ complexMapping1, complexMapping2 };
        }

        Backlog__c backlogData = new Backlog__c();
        backlogData.Business_Value__c = 8;
        backlogData.Status__c = DEFECT_STATUS;
        backlogData.Summary__c = 'This might be a bug';

        String feedbackData = JSON.serialize( backlogData );

        Test.startTest();

           FeedbackRestService.Response response = FeedbackRestService.create(feedbackData, apiSettings.Org_Id__c);

        Test.stopTest();

        System.assert(response.success, 'The request should be successful');

        List<Backlog__c> backlogs = [ SELECT Id, Name, Business_Value__c, Description__c, RecordTypeId FROM Backlog__c ];

        System.assertEquals( 1, backlogs.size(), 'One backlog record should have been created');

        Backlog__c createdBacklog = backlogs[0];
        System.assertEquals( createdBacklog.Id, response.createdId, 'The response Id should be set');
        System.assertEquals( createdBacklog.Name, response.createdName, 'The created record Name should be set in the reponse');


        System.assertEquals( complexMapping1.Target_Value__c, createdBacklog.RecordTypeId, 'The target value from the complex mapping should be populated in the target field when the mapping evaluates to true');
        System.assertEquals( backlogData.Business_Value__c, createdBacklog.Business_Value__c, 'Fields on the backlog should be mapped using the feedback mapping');
        System.assertEquals( null, backlogData.Description__c, 'complex mapping criteria that are not met should not be evaluated');
    }

    static testMethod void create_backlogWithComplexMapping_mergeField()
    {
        final String DEFECT_STATUS = 'Bug';
        setup();

        Feedback_API_Mapping__c complexMapping1 = TestingUtils.createFeedackAPIMapping(SObjectServices.getFullyQualifiedName('Status__c'), SObjectServices.getFullyQualifiedName('Summary__c'));
        complexMapping1.Is_Complex__c = true;
        complexMapping1.Target_Value__c = '{!' + SObjectServices.getFullyQualifiedName('Status__c') + '} - ' + '{!' + SObjectServices.getFullyQualifiedName('Summary__c') + '}';

        System.runAs( TestingUtils.ADMIN_USER ) {
           update complexMapping1;
        }

        Backlog__c backlogData = new Backlog__c();
        backlogData.Business_Value__c = 8;
        backlogData.Status__c = DEFECT_STATUS;
        backlogData.Summary__c = 'This might be a bug';

        String expectedResult = backlogData.Status__c + ' - ' + backlogData.Summary__c;

        String feedbackData = JSON.serialize( backlogData );

        Test.startTest();

           FeedbackRestService.Response response = FeedbackRestService.create(feedbackData, apiSettings.Org_Id__c);

        Test.stopTest();

        System.assert(response.success, 'The request should be successful');

        List<Backlog__c> backlogs = [ SELECT Id, Name, Business_Value__c, Description__c, Summary__c FROM Backlog__c ];

        System.assertEquals( 1, backlogs.size(), 'One backlog record should have been created');

        Backlog__c createdBacklog = backlogs[0];
        System.assertEquals( createdBacklog.Id, response.createdId, 'The response Id should be set');
        System.assertEquals( createdBacklog.Name, response.createdName, 'The created record Name should be set in the reponse');


        System.assertEquals( expectedResult, createdBacklog.Summary__c, 'The target value from the complex mapping should be populated in the target field with merge fields evaluated');
        System.assertEquals( backlogData.Business_Value__c, createdBacklog.Business_Value__c, 'Fields on the backlog should be mapped using the feedback mapping');
    }

    static List<Feedback_API_Mapping__c> createFeedbackMapping()
    {
        Feedback_API_Mapping__c fieldMapping1 = TestingUtils.createFeedackAPIMapping(SObjectServices.getFullyQualifiedName('Business_Value__c'), SObjectServices.getFullyQualifiedName('Business_Value__c'));
        Feedback_API_Mapping__c fieldMapping2 = TestingUtils.createFeedackAPIMapping( SObjectServices.getFullyQualifiedName('Description__c'), SObjectServices.getFullyQualifiedName('Solution__c'));

        return new List<Feedback_API_Mapping__c> { fieldMapping1, fieldMapping2 };
    }
}