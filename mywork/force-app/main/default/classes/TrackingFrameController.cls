global with sharing class TrackingFrameController {

        public String actionTarget {get; set;}

        public TrackingFrameController(ApexPages.StandardController sc) {
            Sobject sobj = sc.getRecord();
            Schema.DescribeSObjectResult describe = sobj.getSObjectType().getDescribe();
            actionTarget = describe.getLocalName();
        }

        @RemoteAction
        global static List<Map<String,String>> getTrackingData(String actionTarget) {

            return MetricsServices.getTrackingData( actionTarget );
        }
}