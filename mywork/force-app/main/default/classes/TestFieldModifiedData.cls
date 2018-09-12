@isTest
private class TestFieldModifiedData {
	static testMethod void constructor_isDeleted() {
		String testEnvironment = 'Test Environment';
		Datetime testLastModifiedDate = Datetime.now();
		String testLastModifiedByName = 'Test Last Modified By Name';
		Datetime testCreatedDate = Datetime.now().addDays(-1);
		String testCreatedByName = 'Test Created By Name';
		Boolean testIsDeleted = true;

		Test.startTest();

			FieldModifiedData fmd = new FieldModifiedData(testEnvironment, testLastModifiedDate, testLastModifiedByName, testCreatedDate, testCreatedByName, testIsDeleted);

		Test.stopTest();

		System.assertEquals(testEnvironment, fmd.environmentName, 'The environment name should match.');
		System.assertEquals(testLastModifiedDate, fmd.lastModifiedDate, 'The last modified date should match.');
		System.assertEquals(testLastModifiedByName, fmd.lastModifiedByName, 'The last modified by name should match.');
		System.assertEquals(testCreatedDate, fmd.createdDate, 'The created date should match.');
		System.assertEquals(testCreatedByName, fmd.createdByName, 'The created by name should match.');
		System.assertEquals(testIsDeleted, fmd.deleted, 'The deleted status should match.');
	}
}