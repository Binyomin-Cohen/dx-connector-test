@isTest
private class TestALMUserServices {

    static testMethod void getRolesByName_valid() {
    	Integer testRoleCount = 3;
    	String testRoleNameBase = 'Test Role ';
    	String testRoleNameFunkyStuff = '#\'"$*)(@œ∑´®†¥_';
    	Set<String> testRoleNames = new Set<String>();
    	List<ALM_User_Role__c> testRoles = new List<ALM_User_Role__c>();

    	for (Integer i = 0; i < testRoleCount; ++i) {
    		String testRoleName = testRoleNameBase + testRoleNameFunkyStuff + String.valueOf(i);
    		testRoleNames.add(testRoleName);
    		testRoles.add(new ALM_User_Role__c(Name=testRoleName));
    	}
    	insert testRoles;

    	Test.startTest();
    		List<ALM_User_Role__c> roles = ALMUserServices.getRolesByName(testRoleNames);
    	Test.stopTest();

    	System.assertEquals(testRoleNames.size(), roles.size(), 'The exact number of roles requested by name should be successfully retrieved.');

    	Set<String> roleNames = new Set<String>();
    	for (ALM_User_Role__c role : roles) {
    		roleNames.add(role.Name);
    	}
    	System.assert(roleNames.containsAll(testRoleNames), 'All specific roles requested by name should be successfully retrieved');
    }
}