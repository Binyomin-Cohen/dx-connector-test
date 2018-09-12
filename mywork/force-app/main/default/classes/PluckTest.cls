@isTest
private class PluckTest
{
	private static testMethod void pluckTest()
	{
		Component__c johnny = new Component__c( Name = 'Johnny', Full_Name__c = 'Five', Description__c = 'Johnny Co' );

		Test.startTest();
			Object actualName = Pluck.pluck( 'Name', johnny );
		Test.stopTest();

		System.assertEquals( johnny.Name, actualName, 'The sObject Name should be plucked' );
	}

	private static testMethod void pluckTest_SObjectField()
	{
		Component__c johnny = new Component__c( Name = 'Johnny', Full_Name__c = 'Five', Description__c = 'Johnny Co' );

		Test.startTest();
			Object actualName = Pluck.pluck( Component__c.Name, johnny );
		Test.stopTest();

		System.assertEquals( johnny.Name, actualName, 'The sObject Name should be plucked' );
	}

	private static testMethod void pluckIgnoresNulls()
	{
		Component__c johnny = new Component__c();

		Test.startTest();
			Set<Object> actualIds = Pluck.pluck( FieldReference.build( 'Id' ), new List<sObject>{ johnny } );
		Test.stopTest();

		System.assert( actualIds.isEmpty(), 'null values should be ignored' );
	}

	private static testMethod void pluckBulkTest()
	{
		Component__c johnny = new Component__c( Name = 'Johnny', Full_Name__c ='Five', Description__c = 'Johnny Co' );
		Component__c julie  = new Component__c( Name = 'Julie', Full_Name__c ='Five', Description__c = 'Julie Co' );
		Component__c jamby = new Component__c( Name = 'Jamby', Full_Name__c ='Five', Description__c = 'Jamby Co' );

		List<Component__c> allLeads = new List<Component__c>{ johnny, julie, jamby };

		Test.startTest();
			Set<Object> actualNames = Pluck.pluck( 'Name', allLeads );
		Test.stopTest();

		System.assert( actualNames.contains( johnny.Name ), 'The Names of the sObjects should be plucked' );
		System.assert( actualNames.contains( julie.Name ), 'The Names of the sObjects should be plucked' );
		System.assert( actualNames.contains( jamby.Name ), 'The Names of the sObjects should be plucked' );
	}

	private static testMethod void pluckBulkTest_SObjectField()
	{
		Component__c johnny = new Component__c( Name = 'Johnny', Full_Name__c ='Five', Description__c = 'Johnny Co' );
		Component__c julie  = new Component__c( Name = 'Julie', Full_Name__c ='Five', Description__c = 'Julie Co' );
		Component__c jamby = new Component__c( Name = 'Jamby', Full_Name__c ='Five', Description__c = 'Jamby Co' );

		List<Component__c> allLeads = new List<Component__c>{ johnny, julie, jamby };

		Test.startTest();
			Set<Object> actualNames = Pluck.pluck( Component__c.Name, allLeads );
		Test.stopTest();

		System.assert( actualNames.contains( johnny.Name ), 'The Names of the sObjects should be plucked' );
		System.assert( actualNames.contains( julie.Name ), 'The Names of the sObjects should be plucked' );
		System.assert( actualNames.contains( jamby.Name ), 'The Names of the sObjects should be plucked' );
	}

	private static testMethod void pluckDateTest()
	{
		Date tomorrow = Date.today().addDays(1);
		Sprint__c bigSale = new Sprint__c( Name = 'Sell a lot', Start_Date__c  = tomorrow, Status__c = 'Qualification' );

		Test.startTest();
			Date actualDate = Pluck.pluckDate( SObjectServices.getFullyQualifiedName('Start_Date__c'), bigSale );
		Test.stopTest();

		System.assertEquals( tomorrow, actualDate, 'The sObject Created Date should be plucked' );
	}
    
	private static testMethod void pluckDateTest_SObjectField()
	{
		Date tomorrow = Date.today().addDays(1);
		Sprint__c bigSale = new Sprint__c( Name = 'Sell a lot', Start_Date__c = tomorrow, Status__c = 'Qualification' );

		Test.startTest();
			Date actualDate = Pluck.pluckDate( Sprint__c.Start_Date__c, bigSale );
		Test.stopTest();

		System.assertEquals( tomorrow, actualDate, 'The sObject Created Date should be plucked' );
	}
	private static testMethod void pluckDatesIgnoresNulls()
	{
		Sprint__c johnny = new Sprint__c();

		Test.startTest();
			Set<Date> actualDates = Pluck.dates( FieldReference.build( SObjectServices.getFullyQualifiedName('Start_Date__c') ), new List<sObject>{ johnny } );
		Test.stopTest();

		System.assert( actualDates.isEmpty(), 'null values should be ignored' );
	}


	private static testMethod void pluckDatesTest()
	{
		Date tomorrow = Date.today().addDays(1);
		Date nextWeek = Date.today().addDays(7);
		Date nextMonth = Date.today().addDays(30);
		Sprint__c bigSale = new Sprint__c( Name = 'Sell a lot', Start_Date__c = tomorrow, Status__c = 'Qualification' );
		Sprint__c biggerSale = new Sprint__c( Name = 'Sell it all', Start_Date__c = nextWeek, Status__c = 'Qualification' );
		Sprint__c biggestSale = new Sprint__c( Name = 'Permanent vacation', Start_Date__c = nextMonth, Status__c = 'Qualification' );

		List<Sprint__c> allOpportunitiesList = new List<Sprint__c>{ bigSale, biggerSale, biggestSale };
		Map<Id, Sprint__c> allOpportunitiesMap = new Map<Id, Sprint__c>{
			SObjectServices.SPRINT_PREFIX + '0000000XXXXX' => bigSale,
			SObjectServices.SPRINT_PREFIX + '0000000XXXXY' => biggerSale,
			SObjectServices.SPRINT_PREFIX + '0000000XXXXZ' => biggestSale
		};

		Test.startTest();
			Set<Date> actualDatesList = Pluck.dates( SObjectServices.getFullyQualifiedName('Start_Date__c'), allOpportunitiesList );
			Set<Date> actualDatesMap = Pluck.dates( SObjectServices.getFullyQualifiedName('Start_Date__c'), allOpportunitiesMap );
		Test.stopTest();

		System.assert( actualDatesList.contains( tomorrow ), 'The sObject Close Date should be plucked' );
		System.assert( actualDatesList.contains( nextWeek ), 'The sObject Close Date should be plucked' );
		System.assert( actualDatesList.contains( nextMonth ), 'The sObject Close Date should be plucked' );
		System.assert( actualDatesMap.contains( tomorrow ), 'The sObject Close Date should be plucked' );
		System.assert( actualDatesMap.contains( nextWeek ), 'The sObject Close Date should be plucked' );
		System.assert( actualDatesMap.contains( nextMonth ), 'The sObject Close Date should be plucked' );
	}

	private static testMethod void pluckDatesTest_SObjectField()
	{
		Date tomorrow = Date.today().addDays(1);
		Date nextWeek = Date.today().addDays(7);
		Date nextMonth = Date.today().addDays(30);
		Sprint__c bigSale = new Sprint__c( Name = 'Sell a lot', Start_Date__c = tomorrow, Status__c = 'Qualification' );
		Sprint__c biggerSale = new Sprint__c( Name = 'Sell it all', Start_Date__c = nextWeek, Status__c = 'Qualification' );
		Sprint__c biggestSale = new Sprint__c( Name = 'Permanent vacation', Start_Date__c = nextMonth, Status__c = 'Qualification' );

		List<Sprint__c> allOpportunitiesList = new List<Sprint__c>{ bigSale, biggerSale, biggestSale };
		Map<Id, Sprint__c> allOpportunitiesMap = new Map<Id, Sprint__c>{
			SObjectServices.SPRINT_PREFIX + '0000000XXXXX' => bigSale,
			SObjectServices.SPRINT_PREFIX + '0000000XXXXY' => biggerSale,
			SObjectServices.SPRINT_PREFIX + '0000000XXXXZ' => biggestSale
		};

		Test.startTest();
			Set<Date> actualDatesList = Pluck.dates( Sprint__c.Start_Date__c, allOpportunitiesList );
			Set<Date> actualDatesMap = Pluck.dates( Sprint__c.Start_Date__c, allOpportunitiesMap );
		Test.stopTest();

		System.assert( actualDatesList.contains( tomorrow ), 'The sObject Close Date should be plucked' );
		System.assert( actualDatesList.contains( nextWeek ), 'The sObject Close Date should be plucked' );
		System.assert( actualDatesList.contains( nextMonth ), 'The sObject Close Date should be plucked' );
		System.assert( actualDatesMap.contains( tomorrow ), 'The sObject Close Date should be plucked' );
		System.assert( actualDatesMap.contains( nextWeek ), 'The sObject Close Date should be plucked' );
		System.assert( actualDatesMap.contains( nextMonth ), 'The sObject Close Date should be plucked' );
	}

	private static testMethod void pluckDatetimeTest()
	{
		Component__c birthdayParty = new Component__c( Overall_Last_Modified_Date__c = DateTime.now() );

		Test.startTest();
			Datetime actualDatetime = Pluck.pluckDatetime( SObjectServices.getFullyQualifiedName('Overall_Last_Modified_Date__c'), birthdayParty );
		Test.stopTest();

		System.assertEquals( birthdayParty.Overall_Last_Modified_Date__c, actualDatetime, 'The sObject Created Date should be plucked' );
	}

	private static testMethod void pluckDatetimeTest_SObjectField()
	{
		Component__c birthdayParty = new Component__c( Overall_Last_Modified_Date__c = DateTime.now() );

		Test.startTest();
			Datetime actualDatetime = Pluck.pluckDatetime( Component__c.Overall_Last_Modified_Date__c, birthdayParty );
		Test.stopTest();

		System.assertEquals( birthdayParty.Overall_Last_Modified_Date__c, actualDatetime, 'The sObject Created Date should be plucked' );
	}

	private static testMethod void pluckDatetimesIgnoresNulls()
	{
		Component__c johnny = new Component__c();

		Test.startTest();
			Set<Datetime> actualDatetimes = Pluck.datetimes( FieldReference.build( SObjectServices.getFullyQualifiedName('Overall_Last_Modified_Date__c') ), new List<sObject>{ johnny } );
		Test.stopTest();

		System.assert( actualDatetimes.isEmpty(), 'null values should be ignored' );
	}

	private static testMethod void pluckDatetimesTest()
	{
		Component__c birthdayParty = new Component__c( Overall_Last_Modified_Date__c = DateTime.now() );
		Component__c cookout = new Component__c( Overall_Last_Modified_Date__c = DateTime.now().addDays( 1 ) );
		Component__c boxSocial = new Component__c( Overall_Last_Modified_Date__c = DateTime.now().addDays( 2 ) );

		List<Component__c> allEvents = new List<Component__c>{ birthdayParty, cookout, boxSocial };
		Map<Id, Component__c> allEventsMap = new Map<Id, Component__c>{
			SObjectServices.COMPONENT_PREFIX + '0000000XXXXU' => birthdayParty,
			SObjectServices.COMPONENT_PREFIX + '0000000XXXXW' => cookout,
			SObjectServices.COMPONENT_PREFIX + '0000000XXXXX' => boxSocial
		};

		Test.startTest();
			Set<Datetime> actualDatetimesList = Pluck.datetimes( SObjectServices.getFullyQualifiedName('Overall_Last_Modified_Date__c'), allEvents );
			Set<Datetime> actualDatetimesMap = Pluck.datetimes( SObjectServices.getFullyQualifiedName('Overall_Last_Modified_Date__c'), allEventsMap );
		Test.stopTest();

		System.assert( actualDatetimesList.contains( birthdayParty.Overall_Last_Modified_Date__c ), 'The sObjects Created Date should be plucked' );
		System.assert( actualDatetimesList.contains( cookout.Overall_Last_Modified_Date__c ), 'The sObjects Created Date should be plucked' );
		System.assert( actualDatetimesList.contains( boxSocial.Overall_Last_Modified_Date__c ), 'The sObjects Created Date should be plucked' );
		System.assert( actualDatetimesMap.contains( birthdayParty.Overall_Last_Modified_Date__c ), 'The sObjects Created Date should be plucked' );
		System.assert( actualDatetimesMap.contains( cookout.Overall_Last_Modified_Date__c ), 'The sObjects Created Date should be plucked' );
		System.assert( actualDatetimesMap.contains( boxSocial.Overall_Last_Modified_Date__c ), 'The sObjects Created Date should be plucked' );
	}

	private static testMethod void pluckDatetimesTest_SObjectField()
	{
		Component__c birthdayParty = new Component__c( Overall_Last_Modified_Date__c = DateTime.now() );
		Component__c cookout = new Component__c( Overall_Last_Modified_Date__c = DateTime.now().addDays( 1 ) );
		Component__c boxSocial = new Component__c( Overall_Last_Modified_Date__c = DateTime.now().addDays( 2 ) );

		List<Component__c> allEvents = new List<Component__c>{ birthdayParty, cookout, boxSocial };
		Map<Id, Component__c> allEventsMap = new Map<Id, Component__c>{
			SObjectServices.COMPONENT_PREFIX + '0000000XXXXU' => birthdayParty,
			SObjectServices.COMPONENT_PREFIX + '0000000XXXXW' => cookout,
			SObjectServices.COMPONENT_PREFIX + '0000000XXXXX' => boxSocial
		};

		Test.startTest();
			Set<Datetime> actualDatetimesList = Pluck.datetimes( Component__c.Overall_Last_Modified_Date__c, allEvents );
			Set<Datetime> actualDatetimesMap = Pluck.datetimes( Component__c.Overall_Last_Modified_Date__c, allEventsMap );
		Test.stopTest();

		System.assert( actualDatetimesList.contains( birthdayParty.Overall_Last_Modified_Date__c ), 'The sObjects Created Date should be plucked' );
		System.assert( actualDatetimesList.contains( cookout.Overall_Last_Modified_Date__c ), 'The sObjects Created Date should be plucked' );
		System.assert( actualDatetimesList.contains( boxSocial.Overall_Last_Modified_Date__c ), 'The sObjects Created Date should be plucked' );
		System.assert( actualDatetimesMap.contains( birthdayParty.Overall_Last_Modified_Date__c ), 'The sObjects Created Date should be plucked' );
		System.assert( actualDatetimesMap.contains( cookout.Overall_Last_Modified_Date__c ), 'The sObjects Created Date should be plucked' );
		System.assert( actualDatetimesMap.contains( boxSocial.Overall_Last_Modified_Date__c ), 'The sObjects Created Date should be plucked' );
	}

	private static testMethod void pluckDecimalTest()
	{
		Decimal tonsOfMoney = 1337.02;
		Backlog__c bigSale = new Backlog__c( Description__c = 'Sell a lot', Closed_Date__c = Date.today(), QA_Effort__c = tonsOfMoney, Status__c = 'Qualification' );

		Test.startTest();
			Decimal actualDecimal = Pluck.pluckDecimal( SObjectServices.getFullyQualifiedName('QA_Effort__c'), bigSale );
		Test.stopTest();

		System.assertEquals( tonsOfMoney, actualDecimal, 'The sObject Amount should be plucked' );
	}

	private static testMethod void pluckDecimalTest_SObjectField()
	{
		Decimal tonsOfMoney = 1337.02;
		Backlog__c bigSale = new Backlog__c( Description__c = 'Sell a lot', Closed_Date__c = Date.today(), QA_Effort__c = tonsOfMoney, Status__c = 'Qualification' );

		Test.startTest();
			Decimal actualDecimal = Pluck.pluckDecimal( Backlog__c.QA_Effort__c, bigSale );
		Test.stopTest();

		System.assertEquals( tonsOfMoney, actualDecimal, 'The sObject Amount should be plucked' );
	}

	private static testMethod void pluckDecimalsIgnoresNulls()
	{
		Deployment_Attempt__c bigSale = new Deployment_Attempt__c();

		Test.startTest();
			Set<Decimal> actualDecimals = Pluck.decimals( FieldReference.build( SObjectServices.getFullyQualifiedName('Number_Components_Total__c') ), new List<sObject>{ bigSale } );
		Test.stopTest();

		System.assert( actualDecimals.isEmpty(), 'null values should be ignored' );
	}

	private static testMethod void pluckDecimalsTest()
	{
		Decimal tonsOfMoney = 1337.02;
		Decimal evenMoreMoney = 42069.96;
		Decimal notALot = 2.13;
		Deployment_Attempt__c bigSale = new Deployment_Attempt__c( UUID__c = 'Sell a lot', End_Date__c = Date.today(), Total_Code_Coverage__c = tonsOfMoney, Status__c = 'Qualification' );
		Deployment_Attempt__c biggerSale = new Deployment_Attempt__c( UUID__c = 'Sell a lot', End_Date__c = Date.today(), Total_Code_Coverage__c = evenMoreMoney, Status__c = 'Qualification' );
		Deployment_Attempt__c smallSale = new Deployment_Attempt__c( UUID__c = 'Sell a lot', End_Date__c = Date.today(), Total_Code_Coverage__c = notALot, Status__c = 'Qualification' );

		List<Deployment_Attempt__c> allOpportunities = new List<Deployment_Attempt__c>{ bigSale, biggerSale, smallSale };
		Map<Id, Deployment_Attempt__c> allOpportunitiesMap = new Map<Id, Deployment_Attempt__c>{
			SObjectServices.DEPLOYMENT_ATTEMPT_PREFIX + '0000000XXXXX' => bigSale,
			SObjectServices.DEPLOYMENT_ATTEMPT_PREFIX + '0000000XXXXY' => biggerSale,
			SObjectServices.DEPLOYMENT_ATTEMPT_PREFIX + '0000000XXXXZ' => smallSale
		};

		Test.startTest();
			Set<Decimal> actualDecimalsList = Pluck.decimals( SObjectServices.getFullyQualifiedName('Total_Code_Coverage__c'), allOpportunities );
			Set<Decimal> actualDecimalsMap = Pluck.decimals( SObjectServices.getFullyQualifiedName('Total_Code_Coverage__c'), allOpportunitiesMap );
		Test.stopTest();

		System.assert( actualDecimalsList.contains( tonsOfMoney ), 'The sObject Amount should be plucked' );
		System.assert( actualDecimalsList.contains( evenMoreMoney ), 'The sObject Amount should be plucked' );
		System.assert( actualDecimalsList.contains( notALot ), 'The sObject Amount should be plucked' );
		System.assert( actualDecimalsMap.contains( tonsOfMoney ), 'The sObject Amount should be plucked' );
		System.assert( actualDecimalsMap.contains( evenMoreMoney ), 'The sObject Amount should be plucked' );
		System.assert( actualDecimalsMap.contains( notALot ), 'The sObject Amount should be plucked' );
	}

	private static testMethod void pluckDecimalsTest_SObjectField()
	{
		Decimal tonsOfMoney = 1337.02;
		Decimal evenMoreMoney = 42069.96;
		Decimal notALot = 2.13;
		Deployment_Attempt__c bigSale = new Deployment_Attempt__c( UUID__c = 'Sell a lot', End_Date__c = Date.today(), Total_Code_Coverage__c = tonsOfMoney, Status__c = 'Qualification' );
		Deployment_Attempt__c biggerSale = new Deployment_Attempt__c( UUID__c = 'Sell a lot', End_Date__c = Date.today(), Total_Code_Coverage__c = evenMoreMoney, Status__c = 'Qualification' );
		Deployment_Attempt__c smallSale = new Deployment_Attempt__c( UUID__c = 'Sell a lot', End_Date__c = Date.today(), Total_Code_Coverage__c = notALot, Status__c = 'Qualification' );

		List<Deployment_Attempt__c> allOpportunities = new List<Deployment_Attempt__c>{ bigSale, biggerSale, smallSale };
		Map<Id, Deployment_Attempt__c> allOpportunitiesMap = new Map<Id, Deployment_Attempt__c>{
			SObjectServices.DEPLOYMENT_ATTEMPT_PREFIX + '0000000XXXXX' => bigSale,
			SObjectServices.DEPLOYMENT_ATTEMPT_PREFIX + '0000000XXXXY' => biggerSale,
			SObjectServices.DEPLOYMENT_ATTEMPT_PREFIX + '0000000XXXXZ' => smallSale
		};

		Test.startTest();
			Set<Decimal> actualDecimalsList = Pluck.decimals( Deployment_Attempt__c.Total_Code_Coverage__c, allOpportunities );
			Set<Decimal> actualDecimalsMap = Pluck.decimals( Deployment_Attempt__c.Total_Code_Coverage__c, allOpportunitiesMap );
		Test.stopTest();

		System.assert( actualDecimalsList.contains( tonsOfMoney ), 'The sObject Amount should be plucked' );
		System.assert( actualDecimalsList.contains( evenMoreMoney ), 'The sObject Amount should be plucked' );
		System.assert( actualDecimalsList.contains( notALot ), 'The sObject Amount should be plucked' );
		System.assert( actualDecimalsMap.contains( tonsOfMoney ), 'The sObject Amount should be plucked' );
		System.assert( actualDecimalsMap.contains( evenMoreMoney ), 'The sObject Amount should be plucked' );
		System.assert( actualDecimalsMap.contains( notALot ), 'The sObject Amount should be plucked' );
	}

	private static testMethod void pluckIntegerTest()
	{
		Integer smallFirm = 60;
		Component__c smallAccount = new Component__c( Instance_Count__c = smallFirm );

		Test.startTest();
			Integer actualInteger = Pluck.pluckInteger( SObjectServices.getFullyQualifiedName('Instance_Count__c'), smallAccount );
		Test.stopTest();

		System.assertEquals( smallFirm, actualInteger, 'The sObject Employees should be plucked' );
	}

	private static testMethod void pluckIntegerTest_SObjectField()
	{
		Integer smallFirm = 60;
		Component__c smallAccount = new Component__c( Instance_Count__c = smallFirm );

		Test.startTest();
			Integer actualInteger = Pluck.pluckInteger( Component__c.Instance_Count__c, smallAccount );
		Test.stopTest();

		System.assertEquals( smallFirm, actualInteger, 'The sObject Employees should be plucked' );
	}

	private static testMethod void pluckIntegersIgnoresNulls()
	{
		Component__c smallAccount = new Component__c();

		Test.startTest();
			Set<Integer> actualIntegers = Pluck.integers( FieldReference.build( SObjectServices.getFullyQualifiedName('Instance_Count__c') ), new List<sObject>{ smallAccount } );
		Test.stopTest();

		System.assert( actualIntegers.isEmpty(), 'null values should be ignored' );
	}

	private static testMethod void pluckIntegersTest()
	{
		Integer smallFirm = 75;
		Integer mediumFirm = 90;
		Integer tinyFirm = 2;
		Component__c smallAccount = new Component__c( Instance_Count__c = smallFirm );
		Component__c mediumAccount = new Component__c( Instance_Count__c = mediumFirm );
		Component__c tinyAccount = new Component__c( Instance_Count__c = tinyFirm );

		List<Component__c> allAccounts = new List<Component__c>{ smallAccount, mediumAccount, tinyAccount };
		Map<Id, Component__c> allAccountsMap = new Map<Id, Component__c>{
			SObjectServices.COMPONENT_PREFIX + '0000000XXXXX' => smallAccount,
			SObjectServices.COMPONENT_PREFIX + '0000000XXXXY' => mediumAccount,
			SObjectServices.COMPONENT_PREFIX + '0000000XXXXZ' => tinyAccount
		};

		Test.startTest();
			Set<Integer> actualIntegersList = Pluck.integers( SObjectServices.getFullyQualifiedName('Instance_Count__c'), allAccounts );
			Set<Integer> actualIntegersMap = Pluck.integers( SObjectServices.getFullyQualifiedName('Instance_Count__c'), allAccountsMap );
		Test.stopTest();

		System.assert( actualIntegersList.contains( smallFirm ), 'The sObject Employees should be plucked' );
		System.assert( actualIntegersList.contains( mediumFirm ), 'The sObject Employees should be plucked' );
		System.assert( actualIntegersList.contains( tinyFirm ), 'The sObject Employees should be plucked' );
		System.assert( actualIntegersMap.contains( smallFirm ), 'The sObject Employees should be plucked' );
		System.assert( actualIntegersMap.contains( mediumFirm ), 'The sObject Employees should be plucked' );
		System.assert( actualIntegersMap.contains( tinyFirm ), 'The sObject Employees should be plucked' );
	}

	private static testMethod void pluckIntegersTest_SObjectField()
	{
		Integer smallFirm = 75;
		Integer mediumFirm = 90;
		Integer tinyFirm = 2;
		Component__c smallAccount = new Component__c( Instance_Count__c = smallFirm );
		Component__c mediumAccount = new Component__c( Instance_Count__c = mediumFirm );
		Component__c tinyAccount = new Component__c( Instance_Count__c = tinyFirm );

		List<Component__c> allAccounts = new List<Component__c>{ smallAccount, mediumAccount, tinyAccount };
		Map<Id, Component__c> allAccountsMap = new Map<Id, Component__c>{
			SObjectServices.COMPONENT_PREFIX + '0000000XXXXX' => smallAccount,
			SObjectServices.COMPONENT_PREFIX + '0000000XXXXY' => mediumAccount,
			SObjectServices.COMPONENT_PREFIX + '0000000XXXXZ' => tinyAccount
		};

		Test.startTest();
			Set<Integer> actualIntegersList = Pluck.integers( Component__c.Instance_Count__c, allAccounts );
			Set<Integer> actualIntegersMap = Pluck.integers( Component__c.Instance_Count__c, allAccountsMap );
		Test.stopTest();

		System.assert( actualIntegersList.contains( smallFirm ), 'The sObject Employees should be plucked' );
		System.assert( actualIntegersList.contains( mediumFirm ), 'The sObject Employees should be plucked' );
		System.assert( actualIntegersList.contains( tinyFirm ), 'The sObject Employees should be plucked' );
		System.assert( actualIntegersMap.contains( smallFirm ), 'The sObject Employees should be plucked' );
		System.assert( actualIntegersMap.contains( mediumFirm ), 'The sObject Employees should be plucked' );
		System.assert( actualIntegersMap.contains( tinyFirm ), 'The sObject Employees should be plucked' );
	}

	private static testMethod void pluckIdTest()
	{
		Component__c johnny = new Component__c( Id = SObjectServices.COMPONENT_PREFIX + '0000000XXXXX', Name = 'Johnny', Full_Name__c ='Five', Description__c = 'Johnny Co' );

		Test.startTest();
			Id actualId = Pluck.pluckId( 'Id', johnny );
		Test.stopTest();

		System.assertEquals( johnny.Id, actualId, 'The sObject id should be plucked' );
	}

	private static testMethod void pluckIdTest_SObjectField()
	{
		Component__c johnny = new Component__c( Id = SObjectServices.COMPONENT_PREFIX + '0000000XXXXX', Name = 'Johnny', Full_Name__c ='Five', Description__c = 'Johnny Co' );

		Test.startTest();
			Id actualId = Pluck.pluckId( Component__c.Id, johnny );
		Test.stopTest();

		System.assertEquals( johnny.Id, actualId, 'The sObject id should be plucked' );
	}

	private static testMethod void pluckIdsIgnoresNulls()
	{
		Component__c johnny = new Component__c();

		Test.startTest();
			Set<Id> actualIds = Pluck.ids( FieldReference.build( 'Id' ), new List<sObject>{ johnny } );
		Test.stopTest();

		System.assert( actualIds.isEmpty(), 'null values should be ignored' );
	}

	private static testMethod void fieldToSObjects()
	{
		final Id OPPTY_1 = SObjectServices.RELEASE_PREFIX + '7000000Us9A1AAJ';
		final Id OPPTY_2 = SObjectServices.RELEASE_PREFIX + '9000000Us7U1AAN';
		Sprint__c oppty1Product1 = new Sprint__c( Id = SObjectServices.SPRINT_PREFIX + '7000000N0aqdAAB', Release__c = OPPTY_1 );
		Sprint__c oppty1Product2  = new Sprint__c( Id = SObjectServices.SPRINT_PREFIX + '7000000N0aqdAAC', Release__c = OPPTY_1 );
		Sprint__c oppty2Product1  = new Sprint__c( Id = SObjectServices.SPRINT_PREFIX + '7000000N0aqdAAD', Release__c = OPPTY_2 );
		Map<Id, Set<sObject>> expectedOpptyToOLI = new Map<Id, Set<sObject>>{ OPPTY_1 => new Set<sObject>{oppty1Product1, oppty1Product2}, OPPTY_2 => new Set<sObject>{oppty2Product1} };

		Test.startTest();
			Map<Id, Set<sObject>> opptyToOLI = Pluck.fieldToSObjects( SObjectServices.getFullyQualifiedName('Release__c'), new List<Sprint__c>{oppty2Product1, oppty1Product1, oppty1Product2});
		Test.stopTest();
		System.assertEquals(2, opptyToOLI.size(), 'There are two distinct opportunity ids in this list of opportunity line items' + opptyToOLI);
		for( Id opptyId : opptyToOLI.keySet() )
		{
			System.assertEquals( true, expectedOpptyToOLI.containsKey( opptyId ) );
			System.assertEquals( expectedOpptyToOLI.get( opptyId ).size(), opptyToOLI.get( opptyId ).size(), 'The number of opportunity line items belonging to this opportunity is' + expectedOpptyToOLI + ':' + opptyToOLI);
			for(sObject oli : expectedOpptyToOLI.get( opptyId ) )
			{
				System.assertEquals( true, opptyToOLI.get( opptyId ).contains( oli ), 'The following opportunity should belong to this opportunity. Opportunity : ' + opptyId + ' oli ' + oli );
			}
		}
	}

	private static testMethod void fieldToSObjects_SObjectField()
	{
		final Id OPPTY_1 = SObjectServices.RELEASE_PREFIX + '7000000Us9A1AAJ';
		final Id OPPTY_2 = SObjectServices.RELEASE_PREFIX + '9000000Us7U1AAN';
		Sprint__c oppty1Product1 = new Sprint__c( Id = SObjectServices.SPRINT_PREFIX + '7000000N0aqdAAB', Release__c = OPPTY_1 );
		Sprint__c oppty1Product2  = new Sprint__c( Id = SObjectServices.SPRINT_PREFIX + '7000000N0aqdAAC', Release__c = OPPTY_1 );
		Sprint__c oppty2Product1  = new Sprint__c( Id = SObjectServices.SPRINT_PREFIX + '7000000N0aqdAAD', Release__c = OPPTY_2 );
		Map<Id, Set<sObject>> expectedOpptyToOLI = new Map<Id, Set<sObject>>{ OPPTY_1 => new Set<sObject>{oppty1Product1, oppty1Product2}, OPPTY_2 => new Set<sObject>{oppty2Product1} };

		Test.startTest();
			Map<Id, Set<sObject>> opptyToOLI = Pluck.fieldToSObjects( Sprint__c.Release__c, new List<Sprint__c>{oppty2Product1, oppty1Product1, oppty1Product2});
		Test.stopTest();
		System.assertEquals(2, opptyToOLI.size(), 'There are two distinct opportunity ids in this list of opportunity line items' + opptyToOLI);
		for( Id opptyId : opptyToOLI.keySet() )
		{
			System.assertEquals( true, expectedOpptyToOLI.containsKey( opptyId ) );
			System.assertEquals( expectedOpptyToOLI.get( opptyId ).size(), opptyToOLI.get( opptyId ).size(), 'The number of opportunity line items belonging to this opportunity is' + expectedOpptyToOLI + ':' + opptyToOLI);
			for(sObject oli : expectedOpptyToOLI.get( opptyId ) )
			{
				System.assertEquals( true, opptyToOLI.get( opptyId ).contains( oli ), 'The following opportunity should belong to this opportunity. Opportunity : ' + opptyId + ' oli ' + oli );
			}
		}
	}

	private static testMethod void pluckIdsTest()
	{
		Component__c johnny = new Component__c( Id = SObjectServices.COMPONENT_PREFIX + '0000000XXXX1', Name = 'Johnny', Full_Name__c ='Five', Description__c = 'Johnny Co' );
		Component__c julie  = new Component__c( Id = SObjectServices.COMPONENT_PREFIX + '0000000XXXX2', Name = 'Julie', Full_Name__c ='Five', Description__c = 'Julie Co' );
		Component__c jamby = new Component__c( Id = SObjectServices.COMPONENT_PREFIX + '0000000XXXX3', Name = 'Jamby', Full_Name__c ='Five', Description__c = 'Jamby Co' );

		List<Component__c> allLeads = new List<Component__c>{ johnny, julie, jamby };
		Map<Id, Component__c> allLeadsMap = new Map<Id, Component__c>{
			SObjectServices.COMPONENT_PREFIX + '0000000XXXXX' => johnny,
			SObjectServices.COMPONENT_PREFIX + '0000000XXXXY' => julie,
			SObjectServices.COMPONENT_PREFIX + '0000000XXXXZ' => jamby
		};

		Test.startTest();
			Set<Id> actualIdsList = Pluck.ids( 'Id', allLeads );
			Set<Id> actualIdsMap = Pluck.ids( 'Id', allLeadsMap );
		Test.stopTest();

		System.assert( actualIdsList.contains( johnny.Id ), 'The Ids of the sObjects should be plucked' );
		System.assert( actualIdsList.contains( julie.Id ), 'The Ids of the sObjects should be plucked' );
		System.assert( actualIdsList.contains( jamby.Id ), 'The Ids of the sObjects should be plucked' );
		System.assert( actualIdsMap.contains( johnny.Id ), 'The Ids of the sObjects should be plucked' );
		System.assert( actualIdsMap.contains( julie.Id ), 'The Ids of the sObjects should be plucked' );
		System.assert( actualIdsMap.contains( jamby.Id ), 'The Ids of the sObjects should be plucked' );
	}

	private static testMethod void pluckIdsTest_SObjectField()
	{
		Component__c johnny = new Component__c( Id = SObjectServices.COMPONENT_PREFIX + '0000000XXXX1', Name = 'Johnny', Full_Name__c ='Five', Description__c = 'Johnny Co' );
		Component__c julie  = new Component__c( Id = SObjectServices.COMPONENT_PREFIX + '0000000XXXX2', Name = 'Julie', Full_Name__c ='Five', Description__c = 'Julie Co' );
		Component__c jamby = new Component__c( Id = SObjectServices.COMPONENT_PREFIX + '0000000XXXX3', Name = 'Jamby', Full_Name__c ='Five', Description__c = 'Jamby Co' );

		List<Component__c> allLeads = new List<Component__c>{ johnny, julie, jamby };
		Map<Id, Component__c> allLeadsMap = new Map<Id, Component__c>{
			SObjectServices.COMPONENT_PREFIX + '0000000XXXXX' => johnny,
			SObjectServices.COMPONENT_PREFIX + '0000000XXXXY' => julie,
			SObjectServices.COMPONENT_PREFIX + '0000000XXXXZ' => jamby
		};

		Test.startTest();
			Set<Id> actualIdsList = Pluck.ids( Component__c.Id, allLeads );
			Set<Id> actualIdsMap = Pluck.ids( Component__c.Id, allLeadsMap );
		Test.stopTest();

		System.assert( actualIdsList.contains( johnny.Id ), 'The Ids of the sObjects should be plucked' );
		System.assert( actualIdsList.contains( julie.Id ), 'The Ids of the sObjects should be plucked' );
		System.assert( actualIdsList.contains( jamby.Id ), 'The Ids of the sObjects should be plucked' );
		System.assert( actualIdsMap.contains( johnny.Id ), 'The Ids of the sObjects should be plucked' );
		System.assert( actualIdsMap.contains( julie.Id ), 'The Ids of the sObjects should be plucked' );
		System.assert( actualIdsMap.contains( jamby.Id ), 'The Ids of the sObjects should be plucked' );
	}

	private static testMethod void pluckIdsModifySetTest()
	{
		Component__c julie  = new Component__c( Id = SObjectServices.COMPONENT_PREFIX + '0000000XXXX2', Name = 'Julie', Full_Name__c ='Five', Description__c = 'Julie Co' );
		Component__c jamby = new Component__c( Id = SObjectServices.COMPONENT_PREFIX + '0000000XXXX3', Name = 'Jamby', Full_Name__c ='Five', Description__c = 'Jamby Co' );

		List<Component__c> allLeads = new List<Component__c>{  julie };

		Test.startTest();
			Set<Id> idsList = Pluck.ids( allLeads );


			idsList.add(jamby.Id);
		Test.stopTest();

        System.assertEquals( 2, idsList.size(), 'The Set returned from pluck.ids should be modifiable');
	}

	private static testMethod void pluckIdsAssumeIdField()
	{
		Component__c jamby = new Component__c( Id = SObjectServices.COMPONENT_PREFIX + '0000000XXXX3', Name = 'Jamby', Full_Name__c ='Five', Description__c = 'Jamby Co' );

		List<Component__c> allLeadsList = new List<Component__c>{ jamby };
		Map<Id, Component__c> allLeadsMap = new Map<Id, Component__c>{ SObjectServices.COMPONENT_PREFIX + '0000000XXXXX' => jamby };

		Test.startTest();
			Set<Id> actualIdsList = Pluck.ids( allLeadsList );
			Set<Id> actualIdsMap = Pluck.ids( allLeadsMap );
		Test.stopTest();

		System.assert( actualIdsList.contains( jamby.Id ), 'The Ids of the sObjects should be plucked from the list' );
		System.assert( actualIdsMap.contains( jamby.Id ), 'The Ids of the sObjects should be plucked from the map' );
	}

	private static testMethod void pluckIdsAssumeIdField_Duplicates()
	{
		final Id DUMMY_LEAD_ID = SObjectServices.COMPONENT_PREFIX + '0000000XXXX3';
		Component__c jamby = new Component__c( Id = DUMMY_LEAD_ID, Name = 'Jamby', Full_Name__c ='Five', Description__c = 'Jamby Co' );
		Component__c jambyDupe = new Component__c( Id = DUMMY_LEAD_ID, Name = 'Jamby', Full_Name__c ='Five', Description__c = 'Jamby Co' );

		List<Component__c> allLeadsList = new List<Component__c>{ jamby, jambyDupe };

		ListException unexpectedListEx;
		Set<Id> actualIds;
		Test.startTest();
			try
			{
				actualIds = Pluck.ids( allLeadsList );
			}
			catch( ListException listEx )
			{
				unexpectedListEx = listEx;
			}
		Test.stopTest();
		System.assertEquals( null, unexpectedListEx, 'There should be no list exception' );
		System.assert( actualIds.contains( jamby.Id ), 'The Ids of the sObjects should be plucked from the list' );
	}

	private static testMethod void pluckStringTest()
	{
		Component__c johnny = new Component__c( Name = 'Johnny', Full_Name__c ='Five', Description__c = 'Johnny Co' );

		Test.startTest();
			String actualName = Pluck.pluckString( 'Name', johnny );
		Test.stopTest();

		System.assertEquals( johnny.Name, actualName, 'The sObject Name should be plucked' );
	}

	private static testMethod void pluckStringTest_SObjectField()
	{
		Component__c johnny = new Component__c( Name = 'Johnny', Full_Name__c ='Five', Description__c = 'Johnny Co' );

		Test.startTest();
			String actualName = Pluck.pluckString( Component__c.Name, johnny );
		Test.stopTest();

		System.assertEquals( johnny.Name, actualName, 'The sObject Name should be plucked' );
	}

	private static testMethod void pluckStringsIgnoresNulls()
	{
		Component__c johnny = new Component__c();

		Test.startTest();
			Set<String> actualStrings = Pluck.strings( FieldReference.build( 'Name' ), new List<sObject>{ johnny } );
		Test.stopTest();

		System.assert( actualStrings.isEmpty(), 'null values should be ignored' );
	}

	private static testMethod void pluckStringsTest()
	{
		Component__c johnny = new Component__c( Name = 'Johnny', Full_Name__c ='Five', Description__c = 'Johnny Co' );
		Component__c julie  = new Component__c( Name = 'Julie', Full_Name__c ='Five', Description__c = 'Julie Co' );
		Component__c jamby = new Component__c( Name = 'Jamby', Full_Name__c ='Five', Description__c = 'Jamby Co' );

		List<Component__c> allLeads = new List<Component__c>{ johnny, julie, jamby };
		Map<Id, Component__c> allLeadsMap = new Map<Id, Component__c>{
			SObjectServices.COMPONENT_PREFIX + '0000000XXXXX' => johnny,
			SObjectServices.COMPONENT_PREFIX + '0000000XXXXY' => julie,
			SObjectServices.COMPONENT_PREFIX + '0000000XXXXZ' => jamby
		};

		Test.startTest();
			Set<String> actualNamesList = Pluck.strings( 'Name', allLeads );
			Set<String> actualNamesMap = Pluck.strings( 'Name', allLeadsMap );
		Test.stopTest();

		System.assert( actualNamesList.contains( johnny.Name ), 'The Names of the sObjects should be plucked' );
		System.assert( actualNamesList.contains( julie.Name ), 'The Names of the sObjects should be plucked' );
		System.assert( actualNamesList.contains( jamby.Name ), 'The Names of the sObjects should be plucked' );
		System.assert( actualNamesMap.contains( johnny.Name ), 'The Names of the sObjects should be plucked' );
		System.assert( actualNamesMap.contains( julie.Name ), 'The Names of the sObjects should be plucked' );
		System.assert( actualNamesMap.contains( jamby.Name ), 'The Names of the sObjects should be plucked' );
	}
	private static testMethod void pluckStringsTest_SObjectField()
	{
		Component__c johnny = new Component__c( Name = 'Johnny', Full_Name__c ='Five', Description__c = 'Johnny Co' );
		Component__c julie  = new Component__c( Name = 'Julie', Full_Name__c ='Five', Description__c = 'Julie Co' );
		Component__c jamby = new Component__c( Name = 'Jamby', Full_Name__c ='Five', Description__c = 'Jamby Co' );

		List<Component__c> allLeads = new List<Component__c>{ johnny, julie, jamby };
		Map<Id, Component__c> allLeadsMap = new Map<Id, Component__c>{
			SObjectServices.COMPONENT_PREFIX + '0000000XXXXX' => johnny,
			SObjectServices.COMPONENT_PREFIX + '0000000XXXXY' => julie,
			SObjectServices.COMPONENT_PREFIX + '0000000XXXXZ' => jamby
		};

		Test.startTest();
			Set<String> actualNamesList = Pluck.strings( Component__c.Name, allLeads );
			Set<String> actualNamesMap = Pluck.strings( Component__c.Name, allLeadsMap );
		Test.stopTest();

		System.assert( actualNamesList.contains( johnny.Name ), 'The Names of the sObjects should be plucked' );
		System.assert( actualNamesList.contains( julie.Name ), 'The Names of the sObjects should be plucked' );
		System.assert( actualNamesList.contains( jamby.Name ), 'The Names of the sObjects should be plucked' );
		System.assert( actualNamesMap.contains( johnny.Name ), 'The Names of the sObjects should be plucked' );
		System.assert( actualNamesMap.contains( julie.Name ), 'The Names of the sObjects should be plucked' );
		System.assert( actualNamesMap.contains( jamby.Name ), 'The Names of the sObjects should be plucked' );
	}

}