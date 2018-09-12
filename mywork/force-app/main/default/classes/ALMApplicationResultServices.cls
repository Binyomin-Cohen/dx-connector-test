public with sharing class ALMApplicationResultServices {

    public static Boolean TRIGGER_HAS_RUN = false;
    @TestVisible
    private static final String PAGE_STATE_TOKEN = 'ALMApplicationResultState';
    public static final string SUCCESS_RESULT_MAP_IDENTIFIER = 'SUCCESS';
    public static final string  COMPLETED_RESULT_MAP_IDENTIFIER = 'COMPLETE';

    public static List<ALMApplicationResultModel> getAlmApplicationResults(String instanceId, ALMJobServices.ToolType toolName) {
        String queryString =
            'SELECT Instance__c, Start_Time__c, Run_Time__c, Result__c, Error_Code__c, Duration__c ' +
            'FROM ALM_Application_Result__c ' +
            'WHERE Instance__c = \'' + String.escapeSingleQuotes(instanceId) + '\' AND Tool__c = \'' + String.escapeSingleQuotes(ALMJobServices.getToolName(toolName)) + '\' ';
        if (toolName == ALMJobServices.ToolType.AUTOMATED_TESTING) {
            queryString += 'AND Result__c != null ';
        }
        queryString +=
            'ORDER BY CreatedDate DESC ' +
            'LIMIT 10';

        List<ALMApplicationResultModel> models = new List<ALMApplicationResultModel>();
        for (ALM_Application_Result__c result : Database.query(queryString)) {
            models.add(new ALMApplicationResultModel(result));
        }

        return models;
    }

    /**
    * Retrieves the most-recently-created test application result for each of a given set of job IDs.
    * @param jobIds - The set of job IDs to retrieve applicaiton results for.
    * @return A map of "job ID => application result".
    */
    public static Map<Id, ALM_Application_Result__c> getLatestInProgressApplicationResultForJobs(Set<Id> jobIds) {
        List<ALM_Job__c> jobs = [
            SELECT Id, (
                SELECT ALM_Job__c, ALM_Job__r.Id, Result__c, Run_Time__c, Warnings__c, Error_Code__c, Error_Message__c
                FROM ALM_Application_Results__r
                WHERE Result__c IN (:SCANServices.TOOL_STATUS_QUEUED, :SCANServices.TOOL_STATUS_RUNNING)
                ORDER BY CreatedDate DESC
                LIMIT 1
            ) FROM ALM_Job__c
            WHERE Id IN :jobIds
        ];

        Map<Id, ALM_Application_Result__c> jobIdToApplicationResult = new Map<Id, ALM_Application_Result__c>();
        for (ALM_Job__c job : jobs) {
            if (!job.ALM_Application_Results__r.isEmpty()) {
                jobIdToApplicationResult.put(job.Id, job.ALM_Application_Results__r[0]);
            }
        }

        return jobIdToApplicationResult;
    }

    /**
    * Return the single most-recent tool result for the given ID/tool pair, or null if none exist.
    * @param instanceId - The ID for which to find the most-recent tool result.
    * @param toolName - The tool which produced the result.
    * @return The application result for the given ID/tool pair.
    */
    public static Map<String, InstanceModel.ScanResult> getLatestAlmApplicationResult(List<String> instanceIds, ALMJobServices.ToolType toolName) {
        Map<String, InstanceModel.ScanResult> scanResultsMap = new Map<String, InstanceModel.ScanResult>();

        if (toolName == ALMJobServices.ToolType.SCAN) {
            ALMApplicationResultServices.ResultState storedState = getScanRunTimesCache();
            Map<Id, ALMApplicationResultServices.InstanceWithLatestAndSuccessfulRunTime> instanceIdToCachedScanResult = storedState.getInstanceTimes();
            for (String instanceId : instanceIds) {
                ALMApplicationResultServices.InstanceWithLatestAndSuccessfulRunTime instanceWithScanRuntime;
                try{
                    instanceWithScanRuntime = instanceIdToCachedScanResult.get(instanceId);
                } catch (System.StringException stringEx) {
                    continue;
                }
                if (instanceWithScanRuntime == null) {
                    scanResultsMap.put(instanceId, new InstanceModel.ScanResult(instanceId));
                } else {
                    ALM_Application_Result__c scanAppResult = new ALM_Application_Result__c(
                                                                    Instance__c = instanceWithScanRuntime.instanceId,
                                                                    Run_Time__c = instanceWithScanRuntime.latestRunTime,
                                                                    Result__c = instanceWithScanRuntime.result);
                    scanResultsMap.put(instanceId, new InstanceModel.ScanResult(scanAppResult));
                }
            }
        } else {

            List<Instances__c> results = [
                                            SELECT Id,
                                              (SELECT Instance__c, Run_Time__c, Result__c
                                                  FROM ALM_Application_Results__r
                                                  WHERE Tool__c = :ALMJobServices.getToolName(toolName) AND Run_Time__c != null
                                                  ORDER BY Run_Time__c DESC NULLS LAST LIMIT 1 )
                                            FROM Instances__c WHERE Id IN :instanceIds
                                          ];


            for (Instances__c instanceRecord : results) {
                String instanceId = instanceRecord.Id;

                List<ALM_Application_Result__c>  applicationResult = instanceRecord.ALM_Application_Results__r;

                if (applicationResult.size() > 0) {
                    scanResultsMap.put(instanceId, new InstanceModel.ScanResult(applicationResult.get(0)));
                } else {
                    scanResultsMap.put(instanceId, new InstanceModel.ScanResult(instanceId));
                }
            }

        }
        return scanResultsMap;
    }

    public static Map<String, List<ALM_Application_Result__c>> filterCompletedSCANJobs(List<ALM_Application_Result__c> records, Map<Id, ALM_Application_Result__c> oldRecords) {
        Map<String, List<ALM_Application_Result__c>> completedRecords = new Map<String, List<ALM_Application_Result__c>>();
        completedRecords.put(SUCCESS_RESULT_MAP_IDENTIFIER, new List<ALM_Application_Result__c>());
        completedRecords.put(COMPLETED_RESULT_MAP_IDENTIFIER, new List<ALM_Application_Result__c>());

        for (ALM_Application_Result__c record : records) {
            if (record.Tool__c == ALMJobServices.getToolName(ALMJobServices.ToolType.SCAN)) {
                if (record.Result__c != null
                   && ScanServices.SUCCESS_STATUSES.contains(record.Result__c.toLowerCase())
                   && record.Result__c != oldRecords.get(record.Id).Result__c) {
                        completedRecords.get(SUCCESS_RESULT_MAP_IDENTIFIER).add(record);
                        completedRecords.get(COMPLETED_RESULT_MAP_IDENTIFIER).add(record);
                   } else if (record.Run_Time__c != null
                              && record.Run_Time__c != oldRecords.get(record.Id).Run_Time__c) {
                        completedRecords.get(COMPLETED_RESULT_MAP_IDENTIFIER).add(record);
                   }
            }
        }

        return completedRecords;
    }

    public static void copyMailToField(List<ALM_Application_Result__c> records) {
        Set<Id> jobIds = new Set<Id>();
        for (ALM_Application_Result__c result : records) {
            jobIds.add(result.ALM_Job__c);
        }
        
        Map<Id, String> jobIdToEmailMap = ALMJobServices.getMailToValues(jobIds);
        
        for (ALM_Application_Result__c result : records) {
            String email = jobIdToEmailMap.get(result.ALM_Job__c);
            if (!String.isBlank(email)) {
                result.Mail_To__c = email;
            }
        }
    }
    
    
    public static void updateMailToOnNonCompletedResults(List<ALM_Job__c> newRecords, Map<Id, ALM_Job__c> oldRecords) {
        List<ALM_Job__c> jobs = [
            SELECT Id, (
                SELECT Id, Mail_To__c
                FROM ALM_Application_Results__r
                Where Result__c = 'Queued' OR Result__c = 'Running'
            ) FROM ALM_Job__c 
            WHERE Id IN :newRecords AND (Status__c = 'Queued' OR Status__c = 'Running')
        ];
        
        Map<Id, List<ALM_Application_Result__c>> jobIdToApplicationResult = new Map<Id, List<ALM_Application_Result__c>>();
        for (ALM_Job__c job : jobs) {
            if (!job.ALM_Application_Results__r.isEmpty()) {
                jobIdToApplicationResult.put(job.Id, job.ALM_Application_Results__r);
            }
        }
        
        Map<Id, ALM_Job__c> jobIdToNewJobMap = new Map<Id, ALM_Job__c>();
        List<ALM_Application_Result__c> resultsToUpdate = new List<ALM_Application_Result__c>();
        for (ALM_Job__c record : newRecords) {
            String recordId = record.Id;
            jobIdToNewJobMap.put(recordId, record);
            
            String newEmail = record.Mail_To__c;
            String oldEmail = oldRecords.get(recordId).Mail_To__c;
            
            if (newEmail != null && !newEmail.equalsIgnoreCase(oldEmail)) {
                List<ALM_Application_Result__c> results = jobIdToApplicationResult.get(recordId);
                if (results != null) {
                    for (ALM_Application_Result__c resultRecord : results) {
                        resultRecord.Mail_To__c = newEmail;
                        resultsToUpdate.add(resultRecord);
                    }
                }
            }
        }
        
        try {
            update resultsToUpdate;
        } catch (DMLException e) {
            for (Integer i = 0; i < e.getNumDml(); i++) {
                Integer failedIndex = e.getDmlIndex(i);
                String failedMessage = e.getDmlMessage(i);
                ALM_Job__c job = jobIdToNewJobMap.get(resultsToUpdate[failedIndex].ALM_Job__c);
                job.addError( failedMessage );
            }
        }
    }
    /**
    * Marks an application result as a failure.
    * @param applicationResult - The application result to mark as a failure.
    * @param errorMessage - The error message to add to the application result.
    */
    public static void markResultAsFailure(ALM_Application_Result__c applicationResult, String errorMessage) {
        markResultAsFailure(applicationResult, errorMessage, null);
    }

    /**
    * Marks an application result as a failure.
    * @param applicationResult - The application result to mark as a failure.
    * @param errorMessage - The error message to add to the application result.
    * @param errorCode - The error code to add to the application result.
    */
    public static void markResultAsFailure(ALM_Application_Result__c applicationResult, String errorMessage, String errorCode) {
        applicationResult.Result__c = SCANServices.FAILURE_STATUS;
        applicationResult.Error_Message__c = errorMessage;
        applicationResult.Error_Code__c =
            errorCode != null ?
            errorCode :
            errorMessage.abbreviate(ALM_Application_Result__c.Error_Code__c.getDescribe().getLength());
        applicationResult.Run_Time__c = DateTime.now();
    }

    /**
    * Marks an application result as a success.
    * @param applicationResult - The application result to mark as a success.
    */
    public static void markResultAsSuccess(ALM_Application_Result__c applicationResult) {
        applicationResult.Result__c = SCANServices.SUCCESS_STATUS;
        applicationResult.Run_Time__c = DateTime.now();
    }

    /**
    * Appends a warning message to an application result.
    * @param applicationResult - The application result to append a warning to.
    * @param warningMessage - The warning message to append to the application result.
    */
    public static void appendWarning(ALM_Application_Result__c applicationResult, String warningMessage) {
        applicationResult.Warnings__c += '\n' + warningMessage + '\n';
    }

    /**
    * Creates a new ALM_Application_Result__c record and inserts it into the database.
    * @param job - The tool job associated with the new result.
    * @param tool - The type of the tool associated with the new result (e.g. SCAN, Automated Testing, etc.)
    * @param result - The value to initialize the Result__c field with.
    * @return The new ALM_Application_Result__c record.
    * @throws ALMException
    */
    public static ALM_Application_Result__c createApplicationResult(ALM_Job__c job, ALMJobServices.ToolType tool, String result) {
        return createApplicationResult(job, tool, result, null);
    }

    /**
    * Creates a new ALM_Application_Result__c record and inserts it into the database.
    * @param job - The tool job associated with the new result.
    * @param tool - The type of the tool associated with the new result (e.g. SCAN, Automated Testing, etc.)
    * @param result - The value to initialize the Result__c field with.
    * @param startTime - The value to initialize the Start_Time__c field with.
    * @return The new ALM_Application_Result__c record.
    * @throws ALMException
    */
    public static ALM_Application_Result__c createApplicationResult(ALM_Job__c job, ALMJobServices.ToolType tool, String result, DateTime startTime) {
        ALM_Application_Result__c applicationResult = buildApplicationResult(job, tool, result, startTime);

        try {
            insert applicationResult;
        } catch (DMLException e) {
            throw new ALMException(e.getMessage());
        }

        return applicationResult;
    }

    /**
    * Builds a new ALM_Application_Result__c record.
    * @param job - The tool job associated with the new result.
    * @param tool - The type of the tool associated with the new result (e.g. SCAN, Automated Testing, etc.)
    * @param result - The value to initialize the Result__c field with.
    * @return The new ALM_Application_Result__c record.
    * @throws ALMException
    */
    public static ALM_Application_Result__c buildApplicationResult(ALM_Job__c job, ALMJobServices.ToolType tool, String result) {
        return buildApplicationResult(job, tool, result, null);
    }

    /**
    * Builds a new ALM_Application_Result__c record.
    * @param job - The tool job associated with the new result.
    * @param tool - The type of the tool associated with the new result (e.g. SCAN, Automated Testing, etc.)
    * @param result - The value to initialize the Result__c field with.
    * @param startTime - The value to initialize the Start_Time__c field with.
    * @return The new ALM_Application_Result__c record.
    * @throws ALMException
    */
    public static ALM_Application_Result__c buildApplicationResult(ALM_Job__c job, ALMJobServices.ToolType tool, String result, DateTime startTime) {
        return new ALM_Application_Result__c(
            ALM_Job__c = job.Id,
            Instance__c = job.Source_Instance__c,
            Tool__c = ALMJobServices.getToolName(tool),
            Result__c = result,
            Start_Time__c = startTime != null ? startTime : DateTime.now()
        );
    }

    public static ALMApplicationResultServices.ResultState loadPageState() {
        ALMApplicationResultServices.ResultState stateInstance = new ALMApplicationResultServices.ResultState();

        try {
            State.retrieve(stateInstance);
        } catch (State.StateException se) {
            ALMLogServices.error(se, ALMLogServices.Application.ADMIN_CONSOLE);
        } catch (System.JSONException je) {
            ALMLogServices.error(je, ALMLogServices.Application.ADMIN_CONSOLE);
        } catch (Exception e) {
            ALMLogServices.error(e, ALMLogServices.Application.ADMIN_CONSOLE);
            throw new AuraHandledException(e.getMessage());
        }

        return stateInstance;
    }

    public static ALMApplicationResultServices.ResultState getScanRunTimesCache() {
        ALMApplicationResultServices.ResultState storedState = loadPageState();
        Map<Id, ALMApplicationResultServices.InstanceWithLatestAndSuccessfulRunTime> queryProcessedResults = new Map<Id, ALMApplicationResultServices.InstanceWithLatestAndSuccessfulRunTime>();

        if(storedState == null || storedState.getInstanceTimes() == null){
          for (AggregateResult aggResult : [SELECT Instance__r.Id, Instance__r.Name, Result__c, MAX(Run_Time__c)
                                           FROM ALM_Application_Result__c
                                           WHERE Run_Time__c != null
                                           AND Tool__c = :ALMJobServices.getToolName(ALMJobServices.ToolType.SCAN)
                                           GROUP BY Instance__r.Id, Instance__r.Name, Result__c]) {
                                               System.debug(aggResult);
              String instanceName = (String) aggResult.get('Name');
              Id instanceId = (Id) aggResult.get('Id');
              String instanceAppResult = (String) aggResult.get(SObjectServices.getFullyQualifiedName('Result__c'));
              DateTime instanceAppResultTime = (Datetime) aggResult.get('expr0');

              if (instanceName != null) {
                  ALMApplicationResultServices.InstanceWithLatestAndSuccessfulRunTime instanceResultToProcess = queryProcessedResults.get(instanceId);
                  if (instanceResultToProcess == null) {
                     instanceResultToProcess = new ALMApplicationResultServices.InstanceWithLatestAndSuccessfulRunTime(
                         instanceId,
                         instanceName,
                         instanceAppResult,
                         instanceAppResultTime
                     );
                     queryProcessedResults.put(instanceId, instanceResultToProcess);
                  } else {
                      instanceResultToProcess = queryProcessedResults.get(instanceId);
                      instanceResultToProcess.updateLatestRunTimes(instanceAppResult, instanceAppResultTime);
                  }
              }
          }
          State.store(new ALMApplicationResultServices.ResultState(queryProcessedResults));
          storedState = loadPageState();
        }
        return storedState;
    }

    public class ResultState implements State.IStateful {
        private Map<Id, ALMApplicationResultServices.InstanceWithLatestAndSuccessfulRunTime> instancesToRunTimes;

        public ResultState(Map<Id, ALMApplicationResultServices.InstanceWithLatestAndSuccessfulRunTime> instancesToRunTimes) {
            this.instancesToRunTimes = instancesToRunTimes;
        }

        public ResultState() {}

        public String getStateToken() {
            return PAGE_STATE_TOKEN;
        }

        public String serialize() {
            return JSON.serialize( instancesToRunTimes );
        }

        public void deserialize( String state ) {
            instancesToRunTimes = (Map<Id, ALMApplicationResultServices.InstanceWithLatestAndSuccessfulRunTime>) JSON.deserialize( state, Map<Id, ALMApplicationResultServices.InstanceWithLatestAndSuccessfulRunTime>.class );
        }

        public Map<Id, ALMApplicationResultServices.InstanceWithLatestAndSuccessfulRunTime> getInstanceTimes() {
            return instancesToRunTimes;
        }
    }
    public class InstanceWithLatestAndSuccessfulRunTime {
        public String instanceId;
        public String instanceName;
        public String result;
        public DateTime latestRunTime;
        public DateTime latestSuccessfulRuntime;

        public InstanceWithLatestAndSuccessfulRunTime (String instanceId, String instanceName, String result, DateTime resultRunTime) {
            this.instanceId = instanceId;
            this.instanceName = instanceName;
            this.result = result;
            if (SCANServices.SUCCESS_STATUSES.contains(result.toLowerCase())) {
                this.latestSuccessfulRuntime = resultRunTime;
            }
            this.latestRunTime = resultRunTime;
        }
        public void updateLatestRunTimes (String result, DateTime resultRunTime ) {
            Boolean changeResult = false;
            if (SCANServices.SUCCESS_STATUSES.contains(result.toLowerCase())
                && resultRunTime != null
                && latestSuccessfulRuntime < resultRunTime) {
                this.latestSuccessfulRuntime = resultRunTime;
                changeResult = true;
            }
            if (latestRunTime < resultRunTime
                && resultRunTime != null) {
                this.latestRunTime = resultRunTime;
                changeResult = true;
            }
            if (changeResult) {
                this.result = result;
            }
        }
    }
}