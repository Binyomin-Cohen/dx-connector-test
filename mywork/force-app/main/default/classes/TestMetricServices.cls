@isTest
private class TestMetricServices {

    static String metricDataEntry;
    static String objectName;

    static void setup() {
        objectName = Schema.SobjectType.Backlog__c.getLocalName();
        metricDataEntry = MetricsServices.NEW_ACTION_TYPE +
                          MetricsServices.ACTION_SEPARATOR +
                          objectName;
    }

    static testMethod void getTrackingData_noData() {
        setup();
        Test.startTest();
            List<Map<String,String>> result =
                TrackingFrameController.getTrackingData( objectName );
        Test.stopTest();

        System.assertEquals(0, result.size(), 'when there is no metric data, an empty list should be returned' );
    }

    static testMethod void getTrackingData_withAnExistingValue() {
        setup();
        GA_Metrics__c metric = GA_Metrics__c.getInstance();
        metric.Data1__c = metricDataEntry;
        insert metric;

        Test.startTest();
            List<Map<String,String>> result =
                TrackingFrameController.getTrackingData( objectName );
        Test.stopTest();

        System.assertEquals(1, result.size(), 'There should be 1 metric returned.' );
        System.assertEquals(objectName, result[0].get('eventCategory'), 'eventCategory should contain the sobject name');
        System.assertEquals(MetricsServices.NEW_ACTION_TYPE, result[0].get('eventAction'), 'eventAction should contain New');
        System.assertEquals('1', result[0].get('eventValue'), 'eventValue should be 1');

        metric = GA_Metrics__c.getInstance();
        System.assert(String.isEmpty( metric.Data1__c ), 'Data 1 field should be empty');
    }

    static testMethod void getTrackingData_withMultipleExistingValues() {
        setup();
        GA_Metrics__c metric = GA_Metrics__c.getInstance();

        metric.Data1__c = metricDataEntry;
        metric.Data1__c += MetricsServices.METRICS_SEPARATOR + metricDataEntry;
        insert metric;

        Test.startTest();
            List<Map<String,String>> result =
                TrackingFrameController.getTrackingData( objectName );
        Test.stopTest();

        System.assertEquals(1, result.size(), 'There should be 1 metric returned.' );
        System.assertEquals(objectName, result[0].get('eventCategory'), 'eventCategory should contain the sobject name');
        System.assertEquals(MetricsServices.NEW_ACTION_TYPE, result[0].get('eventAction'), 'eventAction should contain New');
        System.assertEquals('2', result[0].get('eventValue'), 'eventValue should be 1');

        metric = GA_Metrics__c.getInstance();
        System.assert(String.isEmpty( metric.Data1__c ), 'Data 1 field should be empty');
    }

    static testMethod void getTrackingData_withMultipleActionTargets() {
        setup();

        String otherAction = MetricsServices.NEW_ACTION_TYPE +
                          MetricsServices.ACTION_SEPARATOR +
                          'Some_Other_Obejct__c';

        GA_Metrics__c metric = GA_Metrics__c.getInstance();
        metric.Data1__c = metricDataEntry;
        metric.Data1__c += MetricsServices.METRICS_SEPARATOR + otherAction;
        insert metric;

        Test.startTest();
            List<Map<String,String>> result =
                TrackingFrameController.getTrackingData( objectName );
        Test.stopTest();

        System.assertEquals(1, result.size(), 'There should be 1 metric returned.' );
        System.assertEquals(objectName, result[0].get('eventCategory'), 'eventCategory should contain the sobject name');
        System.assertEquals(MetricsServices.NEW_ACTION_TYPE, result[0].get('eventAction'), 'eventAction should contain New');
        System.assertEquals('1', result[0].get('eventValue'), 'eventValue should be 1');

        metric = GA_Metrics__c.getInstance();
        System.assertEquals( otherAction, metric.Data1__c, 'Any metrics with other actionTargets should not be removed from the metrics data.');
    }
    
    static testMethod void testTrackNewBacklog() {
        setup();
        
        Test.startTest();

            MetricsServices.trackNewAction(objectName);

        Test.stopTest();

        String expectedMetricsValue = MetricsServices.NEW_ACTION_TYPE + MetricsServices.ACTION_SEPARATOR + objectName;
        System.assertEquals(expectedMetricsValue, GA_Metrics__c.getInstance().Data1__c, 'The new metric should be recorded in the custom setting of the form actionType:actionTarget');
    }

    static testMethod void testTrack_WithExistingData() {
        setup();
        
        String originalValue = 'Foo';
        GA_Metrics__c customSetting = GA_Metrics__c.getInstance();
        customSetting.Data1__c = originalValue;
        insert customSetting;

        Test.startTest();

            MetricsServices.trackNewAction(objectName);

        Test.stopTest();

        customSetting = GA_Metrics__c.getInstance();
        String newMetricValue = MetricsServices.NEW_ACTION_TYPE + MetricsServices.ACTION_SEPARATOR + objectName;
        String expectedValue = originalValue + MetricsServices.METRICS_SEPARATOR + newMetricValue;

        System.assertEquals(expectedValue, customSetting.Data1__c, 'The new metric should be appended to the existing data');
    }

    static testMethod void testTrack_WithExistingData_Overflow() {
        setup();
        
        String originalValue = '';
        for(Integer i = 0; i < 250; i++) {
            originalValue += 'z';
        }
        GA_Metrics__c customSetting = GA_Metrics__c.getInstance();
        customSetting.Data1__c = originalValue;
        insert customSetting;

        Test.startTest();

            MetricsServices.trackNewAction(objectName);

        Test.stopTest();

        customSetting = GA_Metrics__c.getInstance();
        String newMetricValue = MetricsServices.NEW_ACTION_TYPE + MetricsServices.ACTION_SEPARATOR + objectName;

        System.assertEquals(originalValue, customSetting.Data1__c, 'The original metric value should be unchanged');
        System.assertEquals(newMetricValue, customSetting.Data2__c, 'The new metric should be appended to the data2 field when the first field is full');
    }

    static testMethod void testTrack_WithExistingData_MaxOverflow() {
        setup();
        
        String originalValue = '';
        for(Integer i = 0; i < 250; i++) {
            originalValue += 'z';
        }
        GA_Metrics__c customSetting = GA_Metrics__c.getInstance();
        customSetting.Data1__c = originalValue;
        customSetting.Data2__c = originalValue;
        insert customSetting;

        Test.startTest();

            MetricsServices.trackNewAction(objectName);

        Test.stopTest();

        customSetting = GA_Metrics__c.getInstance();
        String newMetricValue = MetricsServices.NEW_ACTION_TYPE + MetricsServices.ACTION_SEPARATOR + objectName;

        System.assertEquals(originalValue, customSetting.Data1__c, 'The original metric value should be unchanged');
        System.assertEquals(originalValue, customSetting.Data2__c, 'The original metric value should be unchanged');
        System.assertEquals(newMetricValue, customSetting.Data3__c, 'The new metric should be appended to the data3 field when the first two fields are full');
    }
}