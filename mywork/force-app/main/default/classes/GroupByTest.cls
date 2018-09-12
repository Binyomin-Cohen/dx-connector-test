@isTest
private class GroupByTest
{
    private static testMethod void testGroupByDates()
    {
        final Date TOMORROW = Date.today().addDays(1);
        final Date NEXT_WEEK = Date.today().addDays(7);

        Sprint__c opportunityTomorrow1 =
            new Sprint__c( Id = SObjectServices.SPRINT_PREFIX + '7000000N0aqdAAB', Start_Date__c = TOMORROW );
        Sprint__c opportunityTomorrow2 =
            new Sprint__c( Id = SObjectServices.SPRINT_PREFIX + '7000000N0aqdAAC', Start_Date__c = TOMORROW );
        Sprint__c opportunityNextWeek  =
            new Sprint__c( Id = SObjectServices.SPRINT_PREFIX + '7000000N0aqdAAD', Start_Date__c = NEXT_WEEK );

        Map<Date, Set<Id>> dateToExpectedIds = new Map<Date, Set<Id>>{
            TOMORROW => new Set<Id>{ opportunityTomorrow1.Id, opportunityTomorrow2.Id },
            NEXT_WEEK => new Set<Id>{ opportunityNextWeek.Id }
        };

        List<sObject> opportunities = new List<Sprint__c>{
            opportunityTomorrow1,
            opportunityTomorrow2,
            opportunityNextWeek
        };

        Test.startTest();

            Map<Date, List<sObject>> dateToOpportunities = GroupBy.dates(SObjectServices.getFullyQualifiedName('Start_Date__c'), opportunities );
            Map<Date, List<sObject>> dateToOpportunitiesSF = GroupBy.dates( Sprint__c.Start_Date__c, opportunities );

        Test.stopTest();

        System.assertEquals( 2, dateToOpportunities.size(),
            'All Close Dates should be keys in the map' );

        for( Date aDate : dateToOpportunities.keySet() )
        {
            System.assert( dateToExpectedIds.containsKey( aDate ),
                'Each Close Date should be a key in the map' );

            Set<Id> expectedIds = dateToExpectedIds.get( aDate );
            List<sObject> actualOpportunities = dateToOpportunities.get( aDate );

            System.assertEquals( expectedIds.size(), actualOpportunities.size(),
                'All the Opportunities should be in the value list' );

            for ( sObject opportunity : actualOpportunities )
            {
                System.assert( expectedIds.contains( opportunity.Id ),
                    'Each of the Opportunties should be in the value list' );
            }
        }

        System.assertEquals(dateToOpportunities, dateToOpportunitiesSF, 'The sobject field version should produce the same map');
    }

    private static testMethod void testGroupByYear_Date()
    {
        final String GROUPING_FIELD = SObjectServices.getFullyQualifiedName('Start_Date__c');
        Date thisYear = Date.newInstance(Date.today().year(), 1, 1 );

        List<sObject> datesThisYear = new List<sObject>();
        for( Integer i = 0; i < 10; i++ )
        {
            Sprint__c opty = new Sprint__c();
            opty.put( GROUPING_FIELD, thisYear.addDays( i ) );
            datesThisYear.add( opty );
        }

        List<sObject> datesLastYear = new List<sObject>();
        for( Integer i = 0; i < 5; i++ )
        {
            Sprint__c opty = new Sprint__c();
            opty.put( GROUPING_FIELD, thisYear.addYears(-1).addDays(i) );
            datesLastYear.add( opty );
        }
        Sprint__c nullDateField = new Sprint__c();
        nullDateField.put( GROUPING_FIELD, null );
        List<sObject> allSObjects = new List<sObject>();
        allSObjects.addAll( datesThisYear );
        allSObjects.addAll( datesLastYear );
        allSObjects.add( nullDateField );

        Test.startTest();
            Map<Integer, List<sObject>> groupedYear = GroupBy.year( GROUPING_FIELD, allSObjects );
            Map<Integer, List<sObject>> groupedYearSF = GroupBy.year( Sprint__c.Start_Date__c, allSObjects );
        Test.stopTest();

        System.assertEquals( 3, groupedYear.size(), 'We expect the all the dates to get grouped by year, including the null sObject' );
        System.assertEquals( datesThisYear.size(), groupedYear.get( thisYear.year() ).size(), 'We all the items for this year to be grouped together' );
        for( sObject record : groupedYear.get( thisYear.year() ) )
        {
            System.assertEquals( thisYear.year(), ((Date)record.get( GROUPING_FIELD )).year(), 'We expect the date to be grouped by the correct year' );
        }

        System.assertEquals( datesLastYear.size(), groupedYear.get( thisYear.year()-1 ).size(), 'We all the items for this year to be grouped together' );
        for( sObject record : groupedYear.get( thisYear.year()-1 ) )
        {
            System.assertEquals( thisYear.year()-1, ((Date)record.get( GROUPING_FIELD )).year(), 'We expect the date to be grouped by the correct year' );
        }

        System.assertEquals( 1, groupedYear.get( null ).size(), 'We expect objects to be grouped by null ' );

        System.assertEquals(groupedYear, groupedYearSF, 'The sobject field version should produce the same map');
    }

    private static testMethod void testGroupByYear_DateTime()
    {
        final String GROUPING_FIELD = SObjectServices.getFullyQualifiedName('Overall_Last_Modified_Date__c');
        DateTime thisYear = DateTime.newInstance( Date.today().year(), 1, 1 );

        List<sObject> datesThisYear = new List<sObject>();
        for( Integer i = 0; i < 10; i++ )
        {
            Component__c evt = new Component__c();
            evt.put( GROUPING_FIELD, thisYear.addDays( i ) );
            datesThisYear.add( evt );
        }

        List<sObject> datesLastYear = new List<sObject>();
        for( Integer i = 0; i < 5; i++ )
        {
            Component__c evt = new Component__c();
            evt.put( GROUPING_FIELD, thisYear.addYears(-1).addDays(i) );
            datesLastYear.add( evt );
        }
        Component__c nullDateField = new Component__c();
        nullDateField.put( GROUPING_FIELD, null );
        List<sObject> allSObjects = new List<sObject>();
        allSObjects.addAll( datesThisYear );
        allSObjects.addAll( datesLastYear );
        allSObjects.add( nullDateField );

        Test.startTest();
            Map<Integer, List<sObject>> groupedYear = GroupBy.year( GROUPING_FIELD, allSObjects );
            Map<Integer, List<sObject>> groupedYearSF = GroupBy.year( Component__c.Overall_Last_Modified_Date__c, allSObjects );
        Test.stopTest();

        System.assertEquals( 3, groupedYear.size(), 'We expect the all the dates to get grouped by year, including the null sObject' );
        System.assertEquals( datesThisYear.size(), groupedYear.get( thisYear.year() ).size(), 'We all the items for this year to be grouped together' );
        for( sObject record : groupedYear.get( thisYear.year() ) )
        {
            System.assertEquals( thisYear.year(), ((DateTime)record.get( GROUPING_FIELD )).year(), 'We expect the date to be grouped by the correct year' );
        }

        System.assertEquals( datesLastYear.size(), groupedYear.get( thisYear.year()-1 ).size(), 'We all the items for this year to be grouped together' );
        for( sObject record : groupedYear.get( thisYear.year()-1 ) )
        {
            System.assertEquals( thisYear.year()-1, ((DateTime)record.get( GROUPING_FIELD )).year(), 'We expect the date to be grouped by the correct year' );
        }

        System.assertEquals( 1, groupedYear.get( null ).size(), 'We expect objects to be grouped by null ' );

        System.assertEquals(groupedYear, groupedYearSF, 'The sobject field version should produce the same map');
    }

    private static testMethod void testGroupByDatetimes()
    {
        final Datetime TOMORROW = DateTime.now().addDays(1);
        final Datetime NEXT_WEEK = DateTime.now().addDays(7);

        Component__c birthdayParty = new Component__c( Id = SObjectServices.COMPONENT_PREFIX + '0000000XXXXU', Overall_Last_Modified_Date__c = TOMORROW );
        Component__c cookout = new Component__c( Id = SObjectServices.COMPONENT_PREFIX + '0000000XXXXW', Overall_Last_Modified_Date__c = TOMORROW );
        Component__c boxSocial = new Component__c( Id = SObjectServices.COMPONENT_PREFIX + '0000000XXXXX', Overall_Last_Modified_Date__c = NEXT_WEEK );

        Map<DateTime, Set<Id>> datetimeToExpectedIds = new Map<DateTime, Set<Id>>{
            TOMORROW => new Set<Id>{ birthdayParty.Id, cookout.Id },
            NEXT_WEEK => new Set<Id>{ boxSocial.Id }
        };

        List<sObject> events = new List<Component__c>{
            birthdayParty,
            cookout,
            boxSocial
        };

        Test.startTest();

            Map<DateTime, List<sObject>> datetimeToEvents = GroupBy.datetimes( SObjectServices.getFullyQualifiedName('Overall_Last_Modified_Date__c'), events );
            Map<DateTime, List<sObject>> datetimeToEventsSF = GroupBy.datetimes( Component__c.Overall_Last_Modified_Date__c, events );

        Test.stopTest();

        System.assertEquals( 2, datetimeToEvents.size(),
            'All Activity Dates should be keys in the map' );

        for( DateTime aDateTime : datetimeToEvents.keySet() )
        {
            System.assert( datetimeToExpectedIds.containsKey( aDateTime ),
                'Each Activity Date should be a key in the map' );

            Set<Id> expectedIds = datetimeToExpectedIds.get( aDateTime );
            List<sObject> actualEvents = datetimeToEvents.get( aDateTime );

            System.assertEquals( expectedIds.size(), actualEvents.size(),
                'All the Events should be in the value list' );

            for ( sObject anEvent : actualEvents )
            {
                System.assert( expectedIds.contains( anEvent.Id ),
                    'Each of the Events should be in the value list' );
            }
        }

        System.assertEquals(datetimeToEvents, datetimeToEventsSF, 'The sobject field version should produce the same map');
    }

    private static testMethod void testGroupByDecimals()
    {
        final Decimal LOTS_OF_MONEY = 42069.96;
        final Decimal NOT_MUCH_MONEY = 2.11;

        Deployment_Attempt__c bigSale =
            new Deployment_Attempt__c( Id = SObjectServices.DEPLOYMENT_ATTEMPT_PREFIX + '7000000N0aqdAAB', Total_Code_Coverage__c = LOTS_OF_MONEY );
        Deployment_Attempt__c anotherBigSale =
            new Deployment_Attempt__c( Id = SObjectServices.DEPLOYMENT_ATTEMPT_PREFIX + '7000000N0aqdAAC', Total_Code_Coverage__c = LOTS_OF_MONEY );
        Deployment_Attempt__c smallSale =
            new Deployment_Attempt__c( Id = SObjectServices.DEPLOYMENT_ATTEMPT_PREFIX + '7000000N0aqdAAD', Total_Code_Coverage__c = NOT_MUCH_MONEY );

        Map<Decimal, Set<Id>> decimalToExpectedIds = new Map<Decimal, Set<Id>>{
            LOTS_OF_MONEY => new Set<Id>{ bigSale.Id, anotherBigSale.Id },
            NOT_MUCH_MONEY => new Set<Id>{ smallSale.Id }
        };

        List<sObject> opportunities = new List<Deployment_Attempt__c>{
            bigSale,
            anotherBigSale,
            smallSale
        };

        Test.startTest();

            Map<Decimal, List<sObject>> decimalToOpportunities = GroupBy.decimals( SObjectServices.getFullyQualifiedName('Total_Code_Coverage__c'), opportunities );
            Map<Decimal, List<sObject>> decimalToOpportunitiesSF = GroupBy.decimals( Deployment_Attempt__c.Total_Code_Coverage__c, opportunities );

        Test.stopTest();

        System.assertEquals( 2, decimalToOpportunities.size(),
            'All Amounts should be keys in the map' );

        for( Decimal aDecimal : decimalToOpportunities.keySet() )
        {
            System.assert( decimalToExpectedIds.containsKey( aDecimal ),
                'Each Amount should be a key in the map' );

            Set<Id> expectedIds = decimalToExpectedIds.get( aDecimal );
            List<sObject> actualOpportunities = decimalToOpportunities.get( aDecimal );

            System.assertEquals( expectedIds.size(), actualOpportunities.size(),
                'All the Opportunities should be in the value list' );

            for ( sObject opportunity : actualOpportunities )
            {
                System.assert( expectedIds.contains( opportunity.Id ),
                    'Each of the Opportunties should be in the value list' );
            }
        }

        System.assertEquals(decimalToOpportunities, decimalToOpportunitiesSF, 'The sobject field version should produce the same map');
    }

    private static testMethod void testGroupByIntegers()
    {
        final Integer SMALL_FIRM = 75;
        final Integer TINY_FIRM = 3;

        Deployment_Attempt__c smallAccount = new Deployment_Attempt__c( Id = SObjectServices.DEPLOYMENT_ATTEMPT_PREFIX + '7000000N0aqdAAA', Number_Components_Total__c = SMALL_FIRM );
        Deployment_Attempt__c littleAccount = new Deployment_Attempt__c( Id = SObjectServices.DEPLOYMENT_ATTEMPT_PREFIX + '7000000N0aqdAAB', Number_Components_Total__c = SMALL_FIRM );
        Deployment_Attempt__c tinyAccount = new Deployment_Attempt__c( Id = SObjectServices.DEPLOYMENT_ATTEMPT_PREFIX + '7000000N0aqdAAC', Number_Components_Total__c = TINY_FIRM );

        Map<Integer, Set<Id>> integerToExpectedIds = new Map<Integer, Set<Id>>{
            SMALL_FIRM => new Set<Id>{ smallAccount.Id, littleAccount.Id },
            TINY_FIRM => new Set<Id>{ tinyAccount.Id }
        };

        List<sObject> accounts = new List<Deployment_Attempt__c>{
            smallAccount,
            littleAccount,
            tinyAccount
        };

        Test.startTest();

            Map<Integer, List<sObject>> integerToAccounts = GroupBy.integers( SObjectServices.getFullyQualifiedName('Number_Components_Total__c'), accounts );
            Map<Integer, List<sObject>> integerToAccountsSF = GroupBy.integers( Deployment_Attempt__c.Number_Components_Total__c, accounts );

        Test.stopTest();

        System.assertEquals( 2, integerToAccounts.size(),
            'All Number of Employees should be keys in the map' );

        for ( Integer anInteger : integerToAccounts.keySet() )
        {
            System.assert( integerToExpectedIds.containsKey( anInteger ),
                'Each Number of Employees should be a key in the map' );

            Set<Id> expectedIds = integerToExpectedIds.get( anInteger );
            List<sObject> actualAccounts = integerToAccounts.get( anInteger );

            System.assertEquals( expectedIds.size(), actualAccounts.size(),
                'All the Accounts should be in the value list' );

            for ( sObject account : actualAccounts )
            {
                System.assert( expectedIds.contains( account.Id ),
                    'Each of the Accounts should be in the value list' );
            }
        }

        System.assertEquals(integerToAccounts, integerToAccountsSF, 'The sobject field version should produce the same map');
    }

    private static testMethod void testGroupByIds()
    {
        final Id OPPORTUNITY_1 = SObjectServices.RELEASE_PREFIX + '7000000Us9A1AAJ';
        final Id OPPORTUNITY_2 = SObjectServices.RELEASE_PREFIX + '9000000Us7U1AAN';

        Sprint__c opportunity1Product1 =
            new Sprint__c( Id = SObjectServices.SPRINT_PREFIX + '7000000N0aqdAAB', Release__c = OPPORTUNITY_1 );
        Sprint__c opportunity1Product2  =
            new Sprint__c( Id = SObjectServices.SPRINT_PREFIX + '7000000N0aqdAAC', Release__c = OPPORTUNITY_1 );
        Sprint__c opportunity2Product1  =
            new Sprint__c( Id = SObjectServices.SPRINT_PREFIX + '7000000N0aqdAAD', Release__c = OPPORTUNITY_2 );

        Map<Id, Set<Id>> opportunityIdToExpectedIds = new Map<Id, Set<Id>>{
            OPPORTUNITY_1 => new Set<Id>{ opportunity1Product1.Id, opportunity1Product2.Id },
            OPPORTUNITY_2 => new Set<Id>{ opportunity2Product1.Id }
        };

        List<sObject> olis = new List<Sprint__c>{
            opportunity2Product1,
            opportunity1Product1,
            opportunity1Product2
        };

        Test.startTest();

            Map<Id, List<sObject>> opportunityIdToOLIs = GroupBy.ids( SObjectServices.getFullyQualifiedName('Release__c'), olis );
            Map<Id, List<sObject>> opportunityIdToOLIsSF = GroupBy.ids( Sprint__c.Release__c, olis );

        Test.stopTest();

        System.assertEquals( 2, opportunityIdToOLIs.size(),
            'All Opportunity Ids should be keys in the map' );

        for( Id opportunityId : opportunityIdToOLIs.keySet() )
        {
            System.assert( opportunityIdToExpectedIds.containsKey( opportunityId ),
                'Each Opportunity Id should be a key in the map' );

            Set<Id> expectedIds = opportunityIdToExpectedIds.get( opportunityId );
            List<sObject> actualOLIs = opportunityIdToOLIs.get( opportunityId );

            System.assertEquals( expectedIds.size(), actualOLIs.size(),
                'All the OLIs should be in the value list' );

            for ( sObject oli : actualOLIs )
            {
                System.assert( expectedIds.contains( oli.Id ),
                    'Each of the child OLIs should be in the value list' );
            }
        }

        System.assertEquals(opportunityIdToOLIs, opportunityIdToOLIsSF, 'The sobject field version should produce the same map');
    }

    private static testMethod void testGroupByStrings()
    {
        final String JOHNNY = 'Johnny';
        final String JULIE = 'Julie';

        Component__c johnnyLead = new Component__c( Id = SObjectServices.COMPONENT_PREFIX + '0000000XXXXX', Full_Name__c = JOHNNY );
        Component__c julieLead = new Component__c( Id = SObjectServices.COMPONENT_PREFIX + '0000000XXXXY', Full_Name__c = JULIE );
        Component__c julie2Lead = new Component__c( Id = SObjectServices.COMPONENT_PREFIX + '0000000XXXXZ', Full_Name__c = JULIE );

        Map<String, Set<Id>> stringToExpectedIds = new Map<String, Set<Id>>{
            JOHNNY => new Set<Id>{ johnnyLead.Id },
            JULIE => new Set<Id>{ julieLead.Id, julie2Lead.Id }
        };

        List<sObject> leads = new List<sObject>{
            johnnyLead,
            julieLead,
            julie2Lead
        };

        Test.startTest();

            Map<String, List<sObject>> stringToLeads = GroupBy.strings( SObjectServices.getFullyQualifiedName('Full_Name__c'), leads );
            Map<String, List<sObject>> stringToLeadsSF = GroupBy.strings( Component__c.Full_Name__c, leads );

        Test.stopTest();

        System.assertEquals( 2, stringToLeads.size(),
            'All the First Names should be keys in the map' );

        for ( String aString : stringToLeads.keySet() )
        {
            System.assert( stringToExpectedIds.containsKey( aString ),
                'Each of the First names should be keys in the map' );

            Set<Id> expectedIds = stringToExpectedIds.get( aString );
            List<sObject> actualLeads = stringToLeads.get( aString );

            System.assertEquals( expectedIds.size(), actualLeads.size(),
                'All the Leads should be in the value list' );

            for ( sObject lead : actualLeads )
            {
                System.assert( expectedIds.contains( lead.Id ),
                    'Each of the Leads should be in the value list' );
            }
        }

        System.assertEquals(stringToLeads, stringToLeadsSF, 'The sobject field version should produce the same map');
    }

    static testMethod void testGroupByBooleans() {
        Component__c doNotCall = new Component__c(Full_Name__c='test',Deleted__c=true);
        Component__c doNotCall2 = new Component__c(Full_Name__c='test2',Deleted__c=true);
        Component__c doCall = new Component__c(Full_Name__c='test3',Deleted__c=false);

        List<Component__c> contacts = new List<Component__c>{doNotCall,doNotCall2,doCall};

        Test.startTest();
            Map<Boolean, List<Component__c>> booleanToContacts = GroupBy.booleans(SObjectServices.getFullyQualifiedName('Deleted__c'), contacts);
            Map<Boolean, List<Component__c>> booleanToContactsSF = GroupBy.booleans(Component__c.Deleted__c, contacts);
        Test.stopTest();

        System.assertEquals(2, booleanToContacts.size(), 'There should be the correct number of key value pairs');
        System.assertEquals(2, booleanToContacts.get(true).size(), 'There should be the correct number of contacts');
        for(Component__c contact : booleanToContacts.get(true)) {
            System.assert(contact.Deleted__c, 'The correct contacts should be in the list');
        }
        System.assertEquals(1, booleanToContacts.get(false).size(), 'There should be the correct number of contacts');
        System.assert(!booleanToContacts.get(false)[0].Deleted__c, 'The correct contact should be in the list');

        System.assertEquals(booleanToContacts, booleanToContactsSF, 'The sobject field version should produce the same map');
    }
}