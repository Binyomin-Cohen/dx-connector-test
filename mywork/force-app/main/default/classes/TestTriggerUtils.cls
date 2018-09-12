@isTest
public class TestTriggerUtils {

	private static testmethod void filterUpdatesByUpdatedField() {
		VC_Repository__c repo1 = TestingUtils.createVcRepository(
				'testRepo1','something@github.com');
		VC_Repository__c repo2 = TestingUtils.createVcRepository(
				'testRepo2','something@github.com');

		List<VC_Repository__c> newRepos = new List<VC_Repository__c>();
		newRepos.add(repo1);
		newRepos.add(repo2);

		Map<Id, VC_Repository__c> oldMap =
			new Map<Id, VC_Repository__c>([SELECT Id, Name, Repository_URL__c FROM VC_Repository__c]);

		repo1.Name = 'Changed Name';
		repo2.Repository_URL__C = 'Changed repo url';

		Test.startTest();
			List<VC_Repository__c> filteredRepos =
					TriggerUtils.filterUpdatesByUpdatedField(newRepos, oldMap, VC_Repository__c.Name);
		Test.stopTest();

		System.assertEquals(1, filteredRepos.size(), 'only one repo should have name changed');
		System.assertEquals(repo1.Name, filteredRepos[0].Name, 'the correct repo should be filtered');


	}
}

