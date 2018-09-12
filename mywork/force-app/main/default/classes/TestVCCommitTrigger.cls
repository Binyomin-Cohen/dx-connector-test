@isTest
public class TestVCCommitTrigger {

	private static List<Backlog__c> insertBacklogItems(Integer count) {
		List<Backlog__c> backlogItems = TestingUtils.createBacklogItems(count, true);
		return [SELECT Id, Name FROM Backlog__c WHERE Id IN :new Map<Id, Backlog__c>(backlogItems).keySet()];
	}

	private static testMethod void linkBacklogItem_emptyBacklogItemField() {
		VC_Commit__c commitRecord = TestingUtils.buildVCCommit('', true);

		Test.startTest();
			insert commitRecord;
		Test.stopTest();

		List<VC_Commit__c> insertedCommit = [SELECT Id, Backlog_Item__c FROM VC_Commit__c WHERE Id=:commitRecord.Id];

		System.assertEquals(1, insertedCommit.size(),
				'There should only have been 1 inserted VC_Commit__c record');
		System.assert(String.isBlank(insertedCommit[0].Backlog_Item__c),
				'The Backlog_Item__c field should be blank because the commit message was blank.');
	}

	private static testMethod void linkBacklogItem_noBacklogInCommitMessage() {
		VC_Commit__c commitRecord = TestingUtils.buildVCCommit(
				'There is no backlog item number here in this message', true);

		Test.startTest();
			insert commitRecord;
		Test.stopTest();

		List<VC_Commit__c> insertedCommit = [SELECT Id, Backlog_Item__c FROM VC_Commit__c WHERE Id=:commitRecord.Id];

		System.assertEquals(1, insertedCommit.size(),
				'There should only have been 1 inserted VC_Commit__c record');
		System.assert(String.isBlank(insertedCommit[0].Backlog_Item__c),
				'The Backlog_Item__c field should be blank because there was no backlog item in the commit message.');
	}

	private static testMethod void linkBacklogItem_populatedBacklogItemInCommitMessage() {
		Backlog__c backlogItem = insertBacklogItems(1)[0];

		String commitMessage = backlogItem.Name + ' - I love breaking builds';
		VC_Commit__c commitRecord = TestingUtils.buildVCCommit(commitMessage, true);

		Test.startTest();
			insert commitRecord;
		Test.stopTest();

		List<VC_Commit__c> insertedCommit = [SELECT Id, Backlog_Item__c FROM VC_Commit__c WHERE Id=:commitRecord.Id];

		System.assertEquals(1, insertedCommit.size(),
				'There should only have been 1 inserted VC_Commit__c record');
		System.assertEquals(backlogItem.Id, insertedCommit[0].Backlog_Item__c,
				'The Backlog_Item__c field should match the Id on the backlog item.');
	}

	private static testMethod void linkBacklogItem_insertMultipleCommits_sameBacklog() {
		Backlog__c backlogItem = insertBacklogItems(1)[0];

		List<VC_Commit__c> vcCommits = new List<VC_Commit__c>{
				TestingUtils.buildVCCommit(backlogItem.Name + ' - I break builds', true),
				TestingUtils.buildVCCommit(backlogItem.Name + ' - I still break builds', true),
				TestingUtils.buildVCCommit(backlogItem.Name + ' - I can\'t stop breaking builds', true)
				};

		Test.startTest();
			insert vcCommits;
		Test.stopTest();

		List<VC_Commit__c> insertedCommits = [
				SELECT Id, Backlog_Item__c
				FROM VC_Commit__c
				WHERE Id=:new Map<Id, VC_Commit__c>(vcCommits).keySet()];

		System.assertEquals(vcCommits.size(), insertedCommits.size(),
				'The size of inserted commits should be the same as the created commits.');
		for (VC_Commit__c vcCommit : insertedCommits) {
			System.assertEquals(backlogItem.Id, vcCommit.Backlog_Item__c,
					'The Backlog_Item__c field on vcCommit should match the backlog item Id.');
		}
	}

	private static testMethod void linkBacklogItem_insertMultipleCommits_differentBacklogs() {
		List<Backlog__c> backlogItems = insertBacklogItems(2);

		VC_Commit__c firstCommit = TestingUtils.buildVCCommit(
						backlogItems[0].Name + ' - I break builds', true);
		VC_Commit__c secondCommit = TestingUtils.buildVCCommit(
						backlogItems[1].Name + ' - I love breaking builds', true);

		List<VC_Commit__c> vcCommits = new List<VC_Commit__c>{ firstCommit, secondCommit };

		Test.startTest();
			insert vcCommits;
		Test.stopTest();

		Map<Id, VC_Commit__c> insertedCommits = new Map<Id, VC_Commit__c>([
				SELECT Id, Backlog_Item__c
				FROM VC_Commit__c
				WHERE Id=:new Map<Id, VC_Commit__c>(vcCommits).keySet()]);

		System.assertEquals(vcCommits.size(), insertedCommits.size(),
				'The size of inserted commits should be the same as the created commits.');
		System.assertEquals(backlogItems[0].Id, insertedCommits.get(firstCommit.Id).Backlog_Item__c,
				'The first commit\'s Backlog_Item__c field should match the first backlog item Id.');
		System.assertEquals(backlogItems[1].Id, insertedCommits.get(secondCommit.Id).Backlog_Item__c,
				'The second commit\'s Backlog_Item__c field should match the second backlog item Id.');
	}

	private static testMethod void linkBacklogItem_populatedBacklogItemField() {
		List<Backlog__c> backlogItems = insertBacklogItems(2);

		VC_Commit__c commitRecord = TestingUtils.buildVCCommit(
						backlogItems[1].Name + ' - I love breaking builds', true);
		commitRecord.Backlog_Item__c = backlogItems[0].Id;

		Test.startTest();
			insert commitRecord;
		Test.stopTest();

		List<VC_Commit__c> insertedCommit = [SELECT Id, Backlog_Item__c FROM VC_Commit__c WHERE Id=:commitRecord.Id];

		System.assertEquals(1, insertedCommit.size(),
				'There should only have been 1 inserted VC_Commit__c record');
		System.assertEquals(backlogItems[0].Id, insertedCommit[0].Backlog_Item__c,
				'The Backlog_Item__c field should not have been updated with the commit message backlog item.');
	}

	private static testMethod void linkBacklogItem_notExternalCommit_formattedCommitMessage() {
		Backlog__c backlogItem = insertBacklogItems(1)[0];

		VC_Commit__c commitRecord = TestingUtils.buildVCCommit(
						backlogItem.Name + ' - I love breaking builds', false);

		Test.startTest();
			insert commitRecord;
		Test.stopTest();

		List<VC_Commit__c> insertedCommit = [SELECT Id, Backlog_Item__c FROM VC_Commit__c WHERE Id=:commitRecord.Id];

		System.assertEquals(1, insertedCommit.size(),
				'There should only have been 1 inserted VC_Commit__c record');
		System.assert(String.isBlank(insertedCommit[0].Backlog_Item__c),
				'The Backlog_Item__c field should not be populated because this is not an external commit.');
	}

	private static testMethod void parseBacklogItem_properFormat() {
		String commitMessage = 'Item-00215 - Correct Format';

		Test.startTest();
			String parsedBacklog = VCServices.parseBacklogItem(commitMessage);
		Test.stopTest();

		System.assertEquals('item-00215', parsedBacklog, 'The backlog name was not parsed properly');
	}

}