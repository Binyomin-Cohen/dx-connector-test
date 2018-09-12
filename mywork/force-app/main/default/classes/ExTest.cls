@isTest
private class ExTest {

    private static final String THIS_CLASS_NAME = 'ExTest';
    private static final String CLASS_QUAL_NAME = 'Class.' + ((SObjectServices.CURRENT_NAMESPACE == '') ? '' : SObjectServices.CURRENT_NAMESPACE + '.') + THIS_CLASS_NAME;

    private static final String NULL_EX_TYPE = 	'System.NullPointerException';
    private static final String DML_EX_TYPE = 	'System.DmlException';

    /////////////////////////////////////////////////////////////////
    //				Unit Tests
    /////////////////////////////////////////////////////////////////



    /////////////////////////////////////////////////////////////////
    //				"End to End" Tests
    /////////////////////////////////////////////////////////////////


    private static testMethod void testClassResolutionOnLowLevel() {
        System.runAs( createUser( 't3ts', getSystemAdministratorProfileId(), true ) ) {

            ExLog.ExLogConfig config = new ExLog.ExLogConfig();
            config.level = ExLog.Level.LOW;

            Test.startTest();
                try {

                    nullPointerException();

                } catch( System.Exception ex ) {

                    ExLog.log( ex, config );

                }
            Test.stopTest();

            List<Logged_Exception__c> resolvedExceptions = [ SELECT Id, Type__c, Class_Name__c, Class_Id__c FROM Logged_Exception__c WHERE CreatedById = :UserInfo.getUserId() ];

            System.assertEquals( 1, resolvedExceptions.size(), 'Logged Exception not properly created.' );



            Logged_Exception__c aLoggedEx = resolvedExceptions[0];

            System.assertEquals( null, aLoggedEx.Class_Name__c, 'Class Name should not be populated when Exception Log Level is set lower than High' );
            System.assertEquals( null, aLoggedEx.Class_Id__c, 'Class ID should not be populated when Exception Log Level is set lower than High' );
        }
    }

    private static testMethod void testClassResolutionOnHighLevel() {
        System.runAs( createUser( 't3ts', getSystemAdministratorProfileId(), true ) ) {

            ExLog.ExLogConfig config = new ExLog.ExLogConfig();
            config.level = ExLog.Level.HIGH;

            Test.startTest();
                try {
                    dmlException();
                } catch( System.Exception ex ) {
                    ExLog.log( ex, config );
                }
            Test.stopTest();

            List<Logged_Exception__c> resolvedExceptions = [ SELECT Id, Type__c, Class_Name__c, Class_Id__c FROM Logged_Exception__c WHERE CreatedById = :UserInfo.getUserId() ];

            System.assertEquals( 1, resolvedExceptions.size(), 'A Logged Exception should be created.' );

            Logged_Exception__c loggedEx = resolvedExceptions[0];

            System.assertEquals(DML_EX_TYPE, loggedEx.Type__c, 'The type should be set on the exception');

            //The class name cannot be determined when running from a managed context because the stack trace isn't accessible
            if (SObjectServices.CURRENT_NAMESPACE == '') {
                Id thisClassesId = [ SELECT Id FROM ApexClass WHERE Name = :THIS_CLASS_NAME ].Id;
                System.assertEquals( CLASS_QUAL_NAME, loggedEx.Class_Name__c, 'Class Name should be populated when Exception Log Level is set to High' );
                System.assertEquals( thisClassesId, loggedEx.Class_Id__c, 'Class ID should be populated when Exception Log Level is set to High' );
            }
        }
    }

    private static testMethod void testSingleDmlException() {

        System.runAs( createUser( 't3ts', getSystemAdministratorProfileId(), true ) ) {

            Test.startTest();

                try {

                    dmlException();

                } catch( System.Exception ex ) {

                    ExLog.log( ex );

                }

            Test.stopTest();

            List<Logged_Exception__c> resolvedExceptions = [ SELECT Id, Type__c FROM Logged_Exception__c WHERE CreatedById = :UserInfo.getUserId() ];

            System.assertEquals( 1, resolvedExceptions.size(), 'Logged Exception not properly created.' );
            System.assertEquals( DML_EX_TYPE, resolvedExceptions[0].Type__c, 'Logged Exception of incorrect type.' );

        }

    }

    private static testMethod void testSingleNullException() {

        System.runAs( createUser( 't3ts', getSystemAdministratorProfileId(), true ) ) {

            Test.startTest();

                try {

                    nullPointerException();

                } catch( System.Exception ex ) {

                    ExLog.log( ex );

                }

            Test.stopTest();

            List<Logged_Exception__c> resolvedExceptions = [ SELECT Id, Type__c FROM Logged_Exception__c WHERE CreatedById = :UserInfo.getUserId() ];

            System.assertEquals( 1, resolvedExceptions.size(), 'Logged Exception not properly created.' );
            System.assertEquals( NULL_EX_TYPE, resolvedExceptions[0].Type__c, 'Logged Exception of incorrect type.' );

        }

    }

    private static testMethod void testFlushableNullExceptionLogs() {

        Integer numOfExceptions = 10;

        System.runAs( createUser( 't3ts', getSystemAdministratorProfileId(), true ) ) {

            ExLog.ExLogConfig config = new ExLog.ExLogConfig();
            config.flushable = true;

            Test.startTest();

                for ( Integer cnt = 0; cnt < numOfExceptions; cnt++ ) {

                    try {

                        nullPointerException();

                    } catch( System.Exception ex ) {

                        ExLog.log( ex, config );

                    }

                }

            Test.stopTest();

            List<Logged_Exception__c> resolvedExceptions = [ SELECT Id FROM Logged_Exception__c WHERE CreatedById = :UserInfo.getUserId() ];

            System.assertEquals( 0, resolvedExceptions.size(), 'Logged Exceptions incorrectly committed to database before calling the flushLogCache method' );

            ExLog.flushLogCache();

            resolvedExceptions = [ SELECT Id FROM Logged_Exception__c WHERE CreatedById = :UserInfo.getUserId() ];

            System.assertEquals( numOfExceptions, resolvedExceptions.size(), 'Incorrect number of Logged Exceptions found after calling the flushLogCache method' );

        }

    }

    /////////////////////////////////////////////////////////////////
    //				Error-generating helper methods
    /////////////////////////////////////////////////////////////////

    private static void nullPointerException() {

        String testString;
        Boolean testBool = testString.startsWith( 'text' );

    }

    private static void dmlException() {

        update new Account();

    }

    /////////////////////////////////////////////////////////////////
    //				test data helper methods
    /////////////////////////////////////////////////////////////////

    private static User ADMIN_USER {
        get {
            if ( ADMIN_USER == null ){
                ADMIN_USER = [SELECT Id FROM User WHERE Profile.Name ='System Administrator' AND isActive = true LIMIT 1];
            }
            return ADMIN_USER;
        }
    }

    private static Id getSystemAdministratorProfileId() {
        return [SELECT Id FROM Profile WHERE Name ='System Administrator' LIMIT 1].Id;
    }

    private static User createUser ( String uname, Id profileId,  Boolean willInsert ) {

            User testUser = new User();
            testUser.LastName = uname ;
            testUser.Alias = uname;
            testUser.Email = uname +'@test.com';
            testUser.Username = uname +'@test.com';
            testUser.CommunityNickname = 'atest'+ uname;
            testUser.TimeZoneSidKey = 'America/New_York';
            testUser.LocaleSidKey = 'en_US';
            testUser.EmailEncodingKey = 'ISO-8859-1';
            testUser.ProfileId = profileId;
            testUser.LanguageLocaleKey = 'en_US';
            testUser.IsActive = true;

            if ( willInsert ) {
                System.runAs( ADMIN_USER ){
                    insert testUser;
                }
            }
        return testUser;
    }


}