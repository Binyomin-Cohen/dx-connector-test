public with sharing class ALMErrorServices {

    public static final String APEX_RECORD_TYPE = 'Apex';
    public static final String COMPONENT_RECORD_TYPE = 'Component';
    public static final String OTHER_RECORD_TYPE = 'Other';
    public static final String CODE_COVERAGE_RECORD_TYPE = 'Code Coverage';
    
    private static Map<String, Schema.RecordTypeInfo> almErrorRecordTypes {
        get {
            if (almErrorRecordTypes == null) {
                almErrorRecordTypes = ALM_Error__c.sObjectType.getDescribe().getRecordTypeInfosByName();
            }

            return almErrorRecordTypes;
        }
        set;
    }

    public static List<ALM_Error__c> getApexErrors(String deploymentId) {
        String recordTypeId = getRecordTypeId(APEX_RECORD_TYPE);

        return [
             SELECT Name, Duration__c, Class__c, Method__c, Type__c, Error_Message__c, Stack_Trace__c, Deployment_Attempt__r.Name
             FROM ALM_ERROR__c
             WHERE Deployment_Attempt__c = :deploymentId AND RecordTypeId = :recordTypeId
        ];
    }

    public static List<ALM_Error__c> getComponentErrors(String deploymentId) {
        String componentRecordTypeId = getRecordTypeId(COMPONENT_RECORD_TYPE);
        String otherRecordTypeId = getOtherRecordTypeId();

        return [
               SELECT Name, Changed__c, Column__c, Component_Name__c, Component_Type__c, Deleted__c, Description__c, Error_Location__c,
                      Error_Message__c, Error_Cause__c, Type__c, Deployment_Attempt__r.Name
               FROM ALM_ERROR__c
               WHERE Deployment_Attempt__c = :deploymentId AND (RecordTypeId = :componentRecordTypeId OR RecordTypeId = :otherRecordTypeId)
        ];
    }

    public static List<ALM_Error__c> getBuildErrors(String buildId) {
        return [
               SELECT Id, Name, Description__c, Error_Cause__c, Component_Type__c,
                  Component_Name__c, Type__c, Parent_Component__c, Status__c
               FROM ALM_Error__c
               WHERE Build__c = :buildId
        ];
    }

    public static List<ALM_Error__c> getCodeCoverageErrors(String deploymentId) {
        String codeCoverageRecordTypeId = getRecordTypeId(CODE_COVERAGE_RECORD_TYPE);
        
        return [
               SELECT Component_Name__c, Error_Message__c, RecordTypeId
               FROM ALM_Error__c
               WHERE Deployment_Attempt__c = :deploymentId AND RecordTypeId = :codeCoverageRecordTypeId
        ];
    }

    public static Map<Id, Integer> getDeploymentAttemptIdsToCodeCoverageErrorCounts(Set<Id> deploymentAttemptIds) {
        String codeCoverageRecordTypeId = getRecordTypeId(CODE_COVERAGE_RECORD_TYPE);
        Map<Id, Integer> deploymentAttemptToErrorCount = new Map<Id, Integer>();
        
        if (deploymentAttemptIds.size() > 0) {
            AggregateResult[] groupedResults =[
                SELECT Deployment_Attempt__c dAttempt, count(Id) cntId
                FROM ALM_Error__c
                WHERE Deployment_Attempt__c in :deploymentAttemptIds AND RecordTypeId = :codeCoverageRecordTypeId
                GROUP BY Deployment_Attempt__c            
            ];

            for (AggregateResult ar : groupedResults)  {
                deploymentAttemptToErrorCount.put(ar.get('dAttempt').toString(), Integer.valueOf(ar.get('cntId')));
            }
        }

        return deploymentAttemptToErrorCount;
    }
    
    /**
    * @return map of Build Id => Number of errors
    */
    public static Map<Id, Integer> getErrorCountsByBuild(Set<Id> buildIds) {
        List<AggregateResult> errorCounts = [
            SELECT Build__c buildId, count(Id) NumberOfErrors
            FROM ALM_Error__c
            WHERE Build__c in :buildIds
            GROUP BY Build__c
        ];

        Map<Id, Integer> errorMap = new Map<Id, Integer>();
        if(errorCounts.isEmpty()) {
            return errorMap;
        }

        for(AggregateResult ar : errorCounts) {
            errorMap.put((Id)ar.get('buildId'), Integer.valueOf(ar.get('NumberOfErrors')));
        }
        return errorMap;
    }

    public static String getOtherRecordTypeId() {
        return getRecordTypeId(OTHER_RECORD_TYPE);
    }

	public static String getCodeCoverageRecordTypeId() {
		return getRecordTypeId(CODE_COVERAGE_RECORD_TYPE);
	}

    public static String getApexRecordTypeId() {
        return getRecordTypeId(APEX_RECORD_TYPE);
    }

    public static ALM_Error__c createALMError(String recordTypeId, String type, Id buildId, String description, String cause) {
        ALM_Error__c error = buildALMError(recordTypeId, type, buildId, description, cause);
        insert error;

        return error;
    }

    public static ALM_Error__c buildALMError(String recordTypeId, String type, Id buildId, String description, String cause) {
        ALM_Error__c error = new ALM_Error__c();
        error.RecordTypeId = recordTypeId;
        error.Type__c = type;
        error.Build__c = buildId;
        error.Description__c = description;
        error.Error_Cause__c = cause == null ? cause : cause.abbreviate(255);

        return error;
    }

    private static String getRecordTypeId(String recordTypeName) {
        Schema.RecordTypeInfo info = almErrorRecordTypes.get(recordTypeName);
        String recordTypeId = info.getRecordTypeId();

        return recordTypeId;
    }

    public static String getValidationRuleMessage(String exceptionMessage) {
        if (exceptionMessage.contains('FIELD_CUSTOM_VALIDATION_EXCEPTION,')) {
            exceptionMessage = System.Label.Custom_Validation_Rule_Error + exceptionMessage.substringBetween('FIELD_CUSTOM_VALIDATION_EXCEPTION,', ': [');
        }
        return exceptionMessage;
    }

}