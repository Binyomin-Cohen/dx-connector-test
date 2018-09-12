public with sharing class MetricsServices {

    public static final String NEW_ACTION_TYPE = 'NEW';
    public static final String ACTION_SEPARATOR = ':';
    public static final String METRICS_SEPARATOR = '|';

    private static final Integer DATA_FIELD_COUNT = 3;

    public static void trackNewAction(String actionTarget) {
        GA_Metrics__c metrics = GA_Metrics__c.getInstance();
        String action = NEW_ACTION_TYPE + ACTION_SEPARATOR + actionTarget;

        for( Integer i = 1; i <= DATA_FIELD_COUNT; i++) {

            String fieldName = SObjectServices.getFullyQualifiedName('Data' + i + '__c');

            String existingMetrics = (String) metrics.get( fieldName );

            String updatedMetrics = sObjectServices.appendValue(existingMetrics, action, METRICS_SEPARATOR);

            if(existingMetrics != updatedMetrics) {
                metrics.put( fieldName,  updatedMetrics);
                break;
            }
        }

        upsertMetrics( metrics );
    }

    public static List<Map<String,String>> getTrackingData(String actionTarget) {
        GA_Metrics__c metrics = GA_Metrics__c.getInstance();

        //{ actionType => { action => actionType, value => 0 }
        Map<String, Map<String,String>> metricsByActionType = new Map<String, Map<String,String>>();

        for( Integer i = 1; i <= DATA_FIELD_COUNT; i++) {
            String fieldName = SObjectServices.getFullyQualifiedName('Data' + i + '__c');
            String existingMetrics = (String) metrics.get( fieldName );

            List<String> unusedMetrics = new List<String>();

            if( !String.isBlank( existingMetrics )) {

                for(String metric : existingMetrics.split( '\\'+ METRICS_SEPARATOR )) {

                    List<String> metricParts = metric.split( ACTION_SEPARATOR );
                    if (metricParts.size() < 2) {
                        continue;
                    }
                    String metricActionTarget = metricParts[1];

                    if( metricActionTarget.equalsIgnoreCase( actionTarget )) {
                        String metricActionType = metricParts[0];

                        populateEventAction( metricsByActionType, metricActionType, actionTarget);
                    }
                    else {
                        unusedMetrics.add( metric );
                    }
                }
            }
            metrics.put( fieldName, String.join( unusedMetrics, METRICS_SEPARATOR ));
        }

        upsertMetrics( metrics );

        return metricsByActionType.values();
    }

    /**
    *   Populates map {metricsByActionType} with event data for sending to Google analytics
    *   @param Map<String, Map<String,String>>  Map to populate
    *   @param String   action type
    *   @param String   action target
    */
    private static void populateEventAction( Map<String, Map<String,String>> metricsByActionType,
        String actionType, String actionTarget ) {

	    if (!metricsByActionType.containsKey( actionType )) {
	        metricsByActionType.put( actionType, new Map<String,String>{
	            'eventCategory' => actionTarget,
	            'eventAction' => actionType,
	            'eventValue' => '0'
	        });
	    }

        Integer value = Integer.valueOf( metricsByActionType.get( actionType ).get( 'eventValue' ) );

        metricsByActionType.get( actionType ).put( 'eventValue', String.valueOf(++value) );
    }

    private static void upsertMetrics(GA_Metrics__c metrics) {
        try {
            upsert metrics;
        }
        catch(System.DMLException de) {
            System.debug(de);
        }
    }
}