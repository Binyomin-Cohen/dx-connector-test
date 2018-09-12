public with sharing class ALMLogServices {

    public enum Application {
        ADMIN_CONSOLE,
        BACKLOG_MANAGEMENT,
        COMPONENT_DOCUMENTATION,
        LOGGER,
        OAUTH,
        PM_POST_INSTALL_SCRIPT,
        SPRINT,
        SCAN,
        SLINGSHOT,
        AUTOMATED_TESTING,
        JENKINS,
        VC,
        APPLICATION_RESULT_CLEANER,
        DX_SCRATCH
    }

    public enum LogLevel {
        ERROR,
        WARNING
    }

    @future(callout=true)
    public static void export() {
        List<Logged_Exception__c> logsToExport = getLogsToExport();

        if (logsToExport.isEmpty()) {
            return;
        }

        //due to the 256k message limit size in SQS, lets only include 15 messages for any request
        final Integer MAX_LOGS_TO_PROCESS = 15;
        Datetime lastExportTime;

        String logEndpoint = ALMRestServices.WEB_SERVICE_URL + '/alm-log';
        for (List<Logged_Exception__c> exceptions : SObjectServices.chunkLists(logsToExport, MAX_LOGS_TO_PROCESS)) {
            LogCreateRequest request = new LogCreateRequest(exceptions);
            try {
                ALMRestServices.makePostRequest(logEndpoint, JSON.serialize(request));
                lastExportTime = exceptions[exceptions.size() - 1].CreatedDate;
            } catch (ALMException ae) {
                error(ae, Application.LOGGER);
                updateLastSyncTime(lastExportTime);
                //can not make additional callouts if logging error
                return;
            }
        }

        updateLastSyncTime(lastExportTime);
    }

    public static void error(Exception ex, Application app) {
        log(ex, app, LogLevel.ERROR);
    }

    public static void warn(Exception ex, Application app) {
        log(ex, app, LogLevel.WARNING);
    }

    private static void log(Exception ex, Application app, LogLevel logLevel) {
        ExLog.log(ex, app, logLevel);
        ALMLogExportScheduler.ensureScheduleExists();
    }

    public static void errorAsync(Exception ex, Application app) {
        logAsync(ex, app, LogLevel.ERROR);
    }

    public static void warnAsync(Exception ex, Application app) {
        logAsync(ex, app, LogLevel.WARNING);
    }

    private static void logAsync(Exception ex, Application app, LogLevel logLevel) {
        System.enqueueJob(new AsyncExLog(ex, app, logLevel));
        ALMLogExportScheduler.ensureScheduleExists();
    }

    private static void updateLastSyncTime(Datetime lastExportTime) {
        if (lastExportTime == null) {
            return;
        }

        ALMSettings__c settings = ALMSettings__c.getOrgDefaults();
        settings.Last_Log_Export_Time__c = lastExportTime;
        try {
            upsert settings;
        } catch(DmlException de) {
            error(de, Application.LOGGER);
        }
    }

    public static List<Logged_Exception__c> getLogsToExport() {
        return [
            SELECT Who__c, Type__c,  Organization_Name__c, Organization_Id__c, Notified__c, Log_Level__c,
             Line_Number__c,  Exception_Description__c, CreatedDate, CreatedById, Class_Name__c,
             Class_Link__c, Class_Id__c, Application__c
            FROM Logged_Exception__c
            WHERE CreatedDate > :ALMSettings__c.getOrgDefaults().Last_Log_Export_Time__c
            ORDER BY CreatedDate ASC
            LIMIT 500
        ];
    }

    public class LogCreateRequest {
        public List<Log> logs;
        public String orgId;

        public LogCreateRequest(List<Logged_Exception__c> exceptions) {
            this.logs = new List<Log>();
            this.orgId = UserInfo.getOrganizationId();
            for(Logged_Exception__c le : exceptions) {
                logs.add( new Log(le) );
            }
        }
    }

    public class Log {
        public String application;
        public String appVersion;
        public String className;
        public String lineNumber;
        public String logLevel;
        public String message;
        public String orgName;
        public String type;
        public String who;

        public Log(Logged_Exception__c le) {
            this.application  = le.Application__c;

            if (SObjectServices.CURRENT_NAMESPACE != '') {
                this.appVersion = System.requestVersion().major() +'.' + System.requestVersion().minor();
            }

            this.className = le.Class_Name__c;
            this.lineNumber = le.Line_Number__c == null ? null : String.valueOf(le.Line_Number__c);
            this.logLevel = le.Log_Level__c;
            this.message = le.Exception_Description__c;
            this.orgName = le.Organization_Name__c;
            this.type = le.Type__c;
            this.who = le.Who__c;
        }
    }
}