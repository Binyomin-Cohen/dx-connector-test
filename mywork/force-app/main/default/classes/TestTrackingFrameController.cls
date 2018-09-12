@isTest
private class TestTrackingFrameController {

    static testMethod void setAction() {
        ApexPages.StandardController sc = new ApexPages.StandardController( new Backlog__c() );
        TrackingFrameController trackingController = new TrackingFrameController( sc );
        System.assertEquals(Backlog__c.sObjectType.getDescribe().getLocalName(), trackingController.actionTarget, 'The action should be set to the local name of the sObject');
    }

    static testMethod void testGetTrackingData() {
        GA_Metrics__c metric = GA_Metrics__c.getInstance();
        metric.Data1__c = MetricsServices.NEW_ACTION_TYPE + MetricsServices.ACTION_SEPARATOR + 'Fake_Object__c';
        insert metric;

        Test.startTest();
            List<Map<String,String>> result =
                TrackingFrameController.getTrackingData( Schema.SobjectType.Backlog__c.getLocalName() );
        Test.stopTest();

        System.assertEquals(0, result.size(), 'There should not be any metrics fro Backlog__c' );
    }
}