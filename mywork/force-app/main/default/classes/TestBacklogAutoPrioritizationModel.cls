@isTest
private class TestBacklogAutoPrioritizationModel {
    private static testMethod void setter_behavior_paramNull() {
        String behavior = null;

        BacklogAutoPrioritizationModel model = new BacklogAutoPrioritizationModel();

        Test.startTest();

            model.setBehavior(behavior);

        Test.stopTest();

        System.assertEquals(BacklogAutoPrioritizationModel.PrioritizationBehavior.OFF, model.behavior, 'The prioritization behavior should default to the "off" behavior.');
    }

    private static testMethod void setter_behavior_paramString_invalid() {
        String behavior = 'Invalid';

        BacklogAutoPrioritizationModel model = new BacklogAutoPrioritizationModel();

        Test.startTest();

            model.setBehavior(behavior);

        Test.stopTest();

        System.assertEquals(BacklogAutoPrioritizationModel.PrioritizationBehavior.OFF, model.behavior, 'The prioritization behavior should default to the "off" behavior.');
    }

    private static testMethod void setter_behavior_paramString_valid_off() {
        String behavior = 'Off';

        BacklogAutoPrioritizationModel model = new BacklogAutoPrioritizationModel();

        Test.startTest();

            model.setBehavior(behavior);

        Test.stopTest();

        System.assertEquals(BacklogAutoPrioritizationModel.PrioritizationBehavior.OFF, model.behavior, 'The prioritization behavior should be set properly.');
    }

    private static testMethod void setter_behavior_paramString_valid_top() {
        String behavior = 'Top';

        BacklogAutoPrioritizationModel model = new BacklogAutoPrioritizationModel();

        Test.startTest();

            model.setBehavior(behavior);

        Test.stopTest();

        System.assertEquals(BacklogAutoPrioritizationModel.PrioritizationBehavior.TOP, model.behavior, 'The prioritization behavior should be set properly.');
    }

    private static testMethod void setter_behavior_paramString_valid_bottom() {
        String behavior = 'Bottom';

        BacklogAutoPrioritizationModel model = new BacklogAutoPrioritizationModel();

        Test.startTest();

            model.setBehavior(behavior);

        Test.stopTest();

        System.assertEquals(BacklogAutoPrioritizationModel.PrioritizationBehavior.BOTTOM, model.behavior, 'The prioritization behavior should be set properly.');
    }

    private static testMethod void constructor_noParams() {
        Test.startTest();

            BacklogAutoPrioritizationModel model = new BacklogAutoPrioritizationModel();

        Test.stopTest();

        System.assertEquals(BacklogItemServices.UNIVERSAL_BACKLOG_ID, model.backlogId, 'The backlog ID should default to the universal backlog ID.');
        System.assertEquals(BacklogAutoPrioritizationModel.PrioritizationBehavior.OFF, model.behavior, 'The prioritization behavior should default to the "off" behavior.');
    }

    private static testMethod void constructor_paramID() {
        Id backlogId = TestingUtils.createRandomFakeSObjectId(Custom_Backlog__c.SObjectType);

        Test.startTest();

            BacklogAutoPrioritizationModel model = new BacklogAutoPrioritizationModel(backlogId);

        Test.stopTest();

        System.assertEquals(backlogId, model.backlogId, 'The backlog ID should be set properly.');
        System.assertEquals(BacklogAutoPrioritizationModel.PrioritizationBehavior.OFF, model.behavior, 'The prioritization behavior should default to the "off" behavior.');
    }

    private static testMethod void constructor_paramEnum() {
        BacklogAutoPrioritizationModel.PrioritizationBehavior behavior = BacklogAutoPrioritizationModel.PrioritizationBehavior.TOP;

        Test.startTest();

            BacklogAutoPrioritizationModel model = new BacklogAutoPrioritizationModel(behavior);

        Test.stopTest();

        System.assertEquals(BacklogItemServices.UNIVERSAL_BACKLOG_ID, model.backlogId, 'The backlog ID should default to the universal backlog ID.');
        System.assertEquals(behavior, model.behavior, 'The prioritization behavior should default to the "off" behavior.');
    }

    private static testMethod void constructor_paramsIDAndEnum() {
        Id backlogId = TestingUtils.createRandomFakeSObjectId(Custom_Backlog__c.SObjectType);
        BacklogAutoPrioritizationModel.PrioritizationBehavior behavior = BacklogAutoPrioritizationModel.PrioritizationBehavior.TOP;

        Test.startTest();

            BacklogAutoPrioritizationModel model = new BacklogAutoPrioritizationModel(backlogId, behavior);

        Test.stopTest();

        System.assertEquals(backlogId, model.backlogId, 'The backlog ID should be set properly.');
        System.assertEquals(behavior, model.behavior, 'The prioritization behavior should be set properly.');
    }

    private static testMethod void constructor_paramsIDAndString_valid() {
        Id backlogId = TestingUtils.createRandomFakeSObjectId(Custom_Backlog__c.SObjectType);
        String behavior = 'Top';

        Test.startTest();

            BacklogAutoPrioritizationModel model = new BacklogAutoPrioritizationModel(backlogId, behavior);

        Test.stopTest();

        System.assertEquals(backlogId, model.backlogId, 'The backlog ID should be set properly.');
        System.assertEquals(BacklogAutoPrioritizationModel.PrioritizationBehavior.TOP, model.behavior, 'The prioritization behavior should be set properly.');
    }

    private static testMethod void constructor_paramsIDAndString_invalid() {
        Id backlogId = TestingUtils.createRandomFakeSObjectId(Custom_Backlog__c.SObjectType);
        String behavior = 'Invalid';

        Test.startTest();

            BacklogAutoPrioritizationModel model = new BacklogAutoPrioritizationModel(backlogId, behavior);

        Test.stopTest();

        System.assertEquals(backlogId, model.backlogId, 'The backlog ID should be set properly.');
        System.assertEquals(BacklogAutoPrioritizationModel.PrioritizationBehavior.OFF, model.behavior, 'The prioritization behavior should default to the "off" behavior.');
    }

    private static testMethod void convertPrioritizationBehaviorStringToEnum_invalid() {
        String behaviorString = 'Invalid';

        Test.startTest();

            BacklogAutoPrioritizationModel.PrioritizationBehavior behaviorEnum = BacklogAutoPrioritizationModel.convertPrioritizationBehaviorStringToEnum(behaviorString);

        Test.stopTest();

        System.assertEquals(null, behaviorEnum, 'The prioritization behavior string should be converted to the null enum.');
    }

    private static testMethod void convertPrioritizationBehaviorStringToEnum_valid_off() {
        String behaviorString = 'Off';

        Test.startTest();

            BacklogAutoPrioritizationModel.PrioritizationBehavior behaviorEnum = BacklogAutoPrioritizationModel.convertPrioritizationBehaviorStringToEnum(behaviorString);

        Test.stopTest();

        System.assertEquals(BacklogAutoPrioritizationModel.PrioritizationBehavior.OFF, behaviorEnum, 'The prioritization behavior string should be converted to the proper enum.');
    }

    private static testMethod void convertPrioritizationBehaviorStringToEnum_valid_top() {
        String behaviorString = 'Top';

        Test.startTest();

            BacklogAutoPrioritizationModel.PrioritizationBehavior behaviorEnum = BacklogAutoPrioritizationModel.convertPrioritizationBehaviorStringToEnum(behaviorString);

        Test.stopTest();

        System.assertEquals(BacklogAutoPrioritizationModel.PrioritizationBehavior.TOP, behaviorEnum, 'The prioritization behavior string should be converted to the proper enum.');
    }

    private static testMethod void convertPrioritizationBehaviorStringToEnum_valid_bottom() {
        String behaviorString = 'Bottom';

        Test.startTest();

            BacklogAutoPrioritizationModel.PrioritizationBehavior behaviorEnum = BacklogAutoPrioritizationModel.convertPrioritizationBehaviorStringToEnum(behaviorString);

        Test.stopTest();

        System.assertEquals(BacklogAutoPrioritizationModel.PrioritizationBehavior.BOTTOM, behaviorEnum, 'The prioritization behavior string should be converted to the proper enum.');
    }

    private static testMethod void getDefaultPrioritizationBehavior() {
        Test.startTest();

            BacklogAutoPrioritizationModel.PrioritizationBehavior behavior = BacklogAutoPrioritizationModel.getDefaultPrioritizationBehavior();

        Test.stopTest();

        System.assertEquals(BacklogAutoPrioritizationModel.PrioritizationBehavior.OFF, behavior, 'The default prioritization behavior should be the "off" behavior.');
    }
}